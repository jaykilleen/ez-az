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

  CHALLENGES = [
    { kind: "highest",     label: "HIGHEST WINS",       hint: "Play your strongest card." },
    { kind: "lowest",      label: "LOWEST WINS",        hint: "The smallest number takes the pot." },
    { kind: "closest_to",  label: "CLOSEST TO 4",       hint: "Get as close to 4 as you can.", target: 4 },
    { kind: "closest_to",  label: "CLOSEST TO 7",       hint: "Aim for 7. Over or under, doesn't matter.", target: 7 },
    { kind: "closest_to",  label: "CLOSEST TO 10",      hint: "10 is the target.", target: 10 },
    { kind: "colour_rules", label: "REDS RULE",         hint: "Only RED cards count. Highest red wins.", colour: "red" },
    { kind: "colour_rules", label: "BLUES RULE",        hint: "Only BLUE cards count. Highest blue wins.", colour: "blue" },
    { kind: "colour_rules", label: "GREENS RULE",       hint: "Only GREEN cards count. Highest green wins.", colour: "green" },
    { kind: "colour_rules", label: "YELLOWS RULE",      hint: "Only YELLOW cards count. Highest yellow wins.", colour: "yellow" },
    { kind: "evens_rule",  label: "EVENS RULE",         hint: "Only even numbers count. Highest even wins." },
    { kind: "odds_rule",   label: "ODDS RULE",          hint: "Only odd numbers count. Highest odd wins." }
  ].freeze

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key
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
    challenge_order = CHALLENGES.sample(TOTAL_ROUNDS)

    s = {
      phase: "reading",
      round: 0,
      total_rounds: TOTAL_ROUNDS,
      challenge_order: challenge_order,
      hands: hands,
      pots: Hash.new { |h, k| h[k] = [] }.merge(player_slots.to_h { |s| [s.to_s, []] }),
      played: {},
      player_slots: player_slots,
      discard: []
    }
    save_session(s)
    s
  end

  def build_deck
    COLOURS.flat_map do |colour|
      (1..13).map { |value| { id: "#{colour[0]}#{value}", value: value, colour: colour } }
    end
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
      card = hand.first
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
      # Single winner takes all played cards
      winner = winners.first
      s[:played].each_value { |c| s[:pots][winner] << c }
    else
      # Tie — each tied winner keeps their own card; others discarded
      s[:played].each do |slot_s, card|
        if winners.include?(slot_s)
          s[:pots][slot_s] << card
        else
          s[:discard] << card
        end
      end
    end

    s[:phase] = "revealed"
    s[:last_winners] = winners
    save_session(s)
    ActionCable.server.broadcast(stream_key, revealed_payload(s))
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
        points: pot.sum { |c| c[:value] },
        cards_won: pot.length
      }
    end.sort_by { |e| -e[:points] }
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

  def pot_scores(s)
    s[:pots].transform_values { |pot| pot.sum { |c| c[:value] } }
  end
end
