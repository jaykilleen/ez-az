class TreasureChannel < ApplicationCable::Channel
  SESSIONS = {}
  SESSIONS_MU = Mutex.new

  COLOURS = %w[red blue green yellow].freeze
  COLOUR_HEX = {
    "red"    => "#ff4757",
    "blue"   => "#3742fa",
    "green"  => "#2ed573",
    "yellow" => "#ffc312"
  }.freeze

  SLOT_COLORS = {
    1 => "#ff4757",
    2 => "#3742fa",
    3 => "#ffa502",
    4 => "#2ed573"
  }.freeze

  TOTAL_ROUNDS = 5
  HAND_SIZE    = 5
  MIN_PLAYERS  = 2

  COLOUR_LABEL = { "red" => "REDS RULE", "blue" => "BLUES RULE", "green" => "GREENS RULE", "yellow" => "YELLOWS RULE" }.freeze

  # The challenge pool is generated per-game (in build_challenge_pool) so the
  # Closest-To targets are randomised each session instead of a fixed 4/7/10.
  STATIC_CHALLENGES = [
    { kind: "highest",     label: "HIGHEST WINS", hint: "Play your strongest card." },
    { kind: "lowest",      label: "LOWEST WINS",  hint: "The smallest number takes the pot." },
    { kind: "evens_rule",  label: "EVENS RULE",   hint: "Only even numbers count. Highest even wins." },
    { kind: "odds_rule",   label: "ODDS RULE",    hint: "Only odd numbers count. Highest odd wins." }
  ].freeze

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key

    # Per-slot stream so we can send a phone its updated hand without
    # broadcasting it to other players.
    if !tv? && (slot = params[:slot].to_i) > 0
      stream_from "#{stream_key}:p#{slot}"
    end

    s = get_session
    return unless s

    # Personalised catch-up: phone gets its current hand back on reconnect.
    if !tv? && (slot = params[:slot].to_i) > 0
      hand = s[:hands] && s[:hands][slot.to_s]
      transmit({ type: "deal", slot: slot, hand: hand }) if hand
    end

    case s[:phase]
    when "reading", "picking"
      transmit(round_payload(s))
      transmit(picking_payload(s)) if s[:phase] == "picking"
    when "revealed"
      transmit(round_payload(s))
      transmit(revealed_payload(s))
    when "game_over"
      transmit(game_over_payload(s))
    end
  end

  def unsubscribed; end

  def start_game(_data)
    return unless tv?
    players = @room.memberships.where(role: :player).order(:slot).pluck(:slot)
    return transmit({ type: "error", message: "Need #{MIN_PLAYERS}+ players" }) if players.length < MIN_PLAYERS

    s = build_session(players)
    @room.update!(state: :playing)
    RoomChannel.game_starting(@room)
    deal_to_players(s)
    broadcast_round(s)
  end

  def start_picking(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "reading"
    s[:phase] = "picking"
    save_session(s)
    ActionCable.server.broadcast(stream_key, picking_payload(s))
  end

  # Phone plays a card from its hand.
  def play_card(data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "picking"

    slot = params[:slot].to_i
    return unless valid_slot?(s, slot)
    return if s[:played].key?(slot.to_s)

    card_id = data["card_id"].to_s
    hand = s[:hands][slot.to_s] || []
    card = hand.find { |c| c[:id] == card_id }
    return unless card

    s[:hands][slot.to_s] = hand - [card]
    s[:played][slot.to_s] = card
    save_session(s)

    expected = active_player_slots(s).length
    ActionCable.server.broadcast(stream_key, {
      type: "player_played",
      slot: slot,
      played_count: s[:played].size,
      expected_count: expected
    })

    advance_to_reveal(s) if s[:played].size >= expected
  end

  # TV calls if the picking timer expires.
  def force_reveal(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "picking"
    autoplay_missing(s)
    advance_to_reveal(s)
  end

  def next_round(_data)
    return unless tv?
    s = get_session
    return unless s

    s[:round] += 1
    if s[:round] >= s[:total_rounds]
      s[:phase] = "game_over"
      save_session(s)
      ActionCable.server.broadcast(stream_key, game_over_payload(s))
    else
      broadcast_round(s)
    end
  end

  private

  def tv?
    params[:role] == "tv"
  end

  def stream_key
    "treasure:#{@room.code}"
  end

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@room.code] }
  end

  def save_session(s)
    SESSIONS_MU.synchronize { SESSIONS[@room.code] = s }
  end

  def build_session(player_slots)
    deck = build_deck.shuffle
    hands = {}
    player_slots.each { |slot| hands[slot.to_s] = deck.shift(HAND_SIZE) }
    challenge_order = build_challenge_pool.sample(TOTAL_ROUNDS)

    s = {
      phase: "reading",
      round: 0,
      total_rounds: TOTAL_ROUNDS,
      challenge_order: challenge_order,
      hands: hands,
      deck: deck,
      pots: Hash.new { |h, k| h[k] = [] }.merge(player_slots.to_h { |s| [s.to_s, []] }),
      played: {},
      player_slots: player_slots,
      discard: []
    }
    save_session(s)
    s
  end

  # Top each player's hand back up to HAND_SIZE from the shared deck.
  # No-op if the deck is empty or a player is already at full hand.
  def refill_hands(s)
    s[:hands].each_value do |hand|
      while hand.length < HAND_SIZE && !s[:deck].empty?
        hand << s[:deck].shift
      end
    end
  end

  def build_deck
    COLOURS.flat_map do |colour|
      (1..13).map { |value| { id: "#{colour[0]}#{value}", value: value, colour: colour } }
    end
  end

  # Build a fresh pool per-session so Closest-To targets vary game to game.
  def build_challenge_pool
    pool = STATIC_CHALLENGES.dup
    # 3 random "Closest to N" targets pulled from 3..11
    (3..11).to_a.sample(3).each do |target|
      pool << { kind: "closest_to", label: "CLOSEST TO #{target}", hint: "Aim for #{target}. Over or under, doesn't matter.", target: target }
    end
    COLOURS.each do |colour|
      pool << {
        kind: "colour_rules",
        label: COLOUR_LABEL[colour],
        hint: "Only #{colour.upcase} cards count. Highest #{colour} wins.",
        colour: colour
      }
    end
    pool
  end

  def deal_to_players(s)
    s[:hands].each do |slot_s, hand|
      ActionCable.server.broadcast(stream_key, {
        type: "deal",
        slot: slot_s.to_i,
        hand: hand
      })
    end
  end

  def current_challenge(s)
    s[:challenge_order][s[:round]]
  end

  def active_player_slots(s)
    present = @room.memberships.where(role: :player).pluck(:slot)
    s[:player_slots] & present
  end

  def valid_slot?(s, slot)
    active_player_slots(s).include?(slot)
  end

  def player_name(slot)
    @room.memberships.find_by(slot: slot)&.name || "Player #{slot}"
  end

  def autoplay_missing(s)
    active_player_slots(s).each do |slot|
      next if s[:played].key?(slot.to_s)
      hand = s[:hands][slot.to_s] || []
      next if hand.empty?
      card = hand.sample
      s[:hands][slot.to_s] = hand - [card]
      s[:played][slot.to_s] = card
    end
    save_session(s)
  end

  def advance_to_reveal(s)
    challenge = current_challenge(s)
    candidates = filter_for(challenge, s[:played])
    winners = candidates.empty? ? [] : pick_winners(challenge, candidates)

    if winners.empty?
      # No one matched — discard everything
      s[:played].each_value { |c| s[:discard] << c }
    elsif winners.length == 1
      # Single winner takes all played cards into their pot
      winner = winners.first
      s[:played].each_value { |c| s[:pots][winner] << c }
    else
      # Tie — each tied player gets their card back in hand; others discarded
      s[:played].each do |slot_s, card|
        if winners.include?(slot_s)
          s[:hands][slot_s] ||= []
          s[:hands][slot_s] << card
        else
          s[:discard] << card
        end
      end
    end

    # Refill hands from the deck (skip on the final round — no point drawing
    # cards that won't be played).
    refill_hands(s) if s[:round] < s[:total_rounds] - 1

    s[:phase] = "revealed"
    s[:last_winners] = winners
    save_session(s)
    ActionCable.server.broadcast(stream_key, revealed_payload(s))

    # Send each player their updated hand on their per-slot stream so the
    # phone UI re-syncs (covers tied cards returned + cards drawn from deck).
    s[:hands].each do |slot_s, hand|
      ActionCable.server.broadcast(
        "#{stream_key}:p#{slot_s}",
        { type: "deal", slot: slot_s.to_i, hand: hand }
      )
    end
  end

  def filter_for(challenge, played)
    case challenge[:kind]
    when "colour_rules"
      played.select { |_, c| c[:colour] == challenge[:colour] }
    when "evens_rule"
      played.select { |_, c| c[:value].even? }
    when "odds_rule"
      played.select { |_, c| c[:value].odd? }
    else
      played.dup
    end
  end

  def pick_winners(challenge, candidates)
    case challenge[:kind]
    when "lowest"
      min_val = candidates.values.map { |c| c[:value] }.min
      candidates.select { |_, c| c[:value] == min_val }.keys
    when "closest_to"
      target = challenge[:target].to_i
      min_dist = candidates.values.map { |c| (c[:value] - target).abs }.min
      candidates.select { |_, c| (c[:value] - target).abs == min_dist }.keys
    else
      max_val = candidates.values.map { |c| c[:value] }.max
      candidates.select { |_, c| c[:value] == max_val }.keys
    end
  end

  def broadcast_round(s)
    s[:phase]   = "reading"
    s[:played]  = {}
    s[:last_winners] = nil
    save_session(s)
    ActionCable.server.broadcast(stream_key, round_payload(s))
  end

  # ── Payload builders ────────────────────────────────────────────────────

  def round_payload(s)
    challenge = current_challenge(s)
    {
      type: "round",
      round: s[:round],
      total: s[:total_rounds],
      challenge: challenge_payload(challenge),
      hands_remaining: s[:hands].transform_values(&:length),
      scores: pot_scores(s)
    }
  end

  def picking_payload(s)
    {
      type: "picking",
      round: s[:round],
      challenge: challenge_payload(current_challenge(s)),
      played_count: s[:played].size,
      expected_count: active_player_slots(s).length
    }
  end

  def revealed_payload(s)
    plays = s[:played].map do |slot_s, card|
      slot = slot_s.to_i
      {
        slot: slot,
        name: player_name(slot),
        slot_color: SLOT_COLORS[slot],
        card: card_view(card),
        winner: (s[:last_winners] || []).include?(slot_s)
      }
    end
    {
      type: "revealed",
      round: s[:round],
      challenge: challenge_payload(current_challenge(s)),
      plays: plays,
      winners: s[:last_winners] || [],
      scores: pot_scores(s),
      pot_counts: s[:pots].transform_values(&:length)
    }
  end

  def game_over_payload(s)
    scoreboard = s[:player_slots].map do |slot|
      pot = s[:pots][slot.to_s] || []
      {
        slot: slot,
        name: player_name(slot),
        slot_color: SLOT_COLORS[slot],
        points: pot.length,
        cards_won: pot.length,
        total_value: pot.sum { |c| c[:value] }
      }
    end.sort_by { |e| [-e[:points], -e[:total_value]] }
    { type: "game_over", scores: scoreboard }
  end

  def state_snapshot(s)
    {
      type: "snapshot",
      phase: s[:phase],
      round: s[:round],
      total: s[:total_rounds],
      challenge: current_challenge(s) ? challenge_payload(current_challenge(s)) : nil,
      hands_remaining: s[:hands].transform_values(&:length),
      scores: pot_scores(s),
      played_count: s[:played].size,
      expected_count: active_player_slots(s).length
    }
  end

  def challenge_payload(c)
    {
      kind: c[:kind],
      label: c[:label],
      hint: c[:hint],
      colour: c[:colour],
      target: c[:target]
    }.compact
  end

  def card_view(c)
    { id: c[:id], value: c[:value], colour: c[:colour], hex: COLOUR_HEX[c[:colour]] }
  end

  # Primary score is card count (every round won is equally rewarding,
  # regardless of whether the challenge made you play high or low cards).
  def pot_scores(s)
    s[:pots].transform_values(&:length)
  end

  def pot_values(s)
    s[:pots].transform_values { |pot| pot.sum { |c| c[:value] } }
  end
end
