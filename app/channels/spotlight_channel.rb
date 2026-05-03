class SpotlightChannel < ApplicationCable::Channel
  SESSIONS = {}
  SESSIONS_MU = Mutex.new

  QUESTIONS = YAML.load_file(
    Rails.root.join("db/questions/spotlight.yml"),
    permitted_classes: [], aliases: true
  ).map(&:symbolize_keys).freeze

  SLOT_COLORS = {
    1 => "#ff4757",
    2 => "#3742fa",
    3 => "#ffa502",
    4 => "#2ed573"
  }.freeze

  ROUNDS_PER_PLAYER = 2
  MAX_ANSWER_LEN    = 80
  MIN_PLAYERS       = 2

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key
    s = get_session
    return unless s

    # Catch up a late-joining client (TV reload, phone reconnect)
    transmit(question_payload(s))
    transmit(answering_payload(s))     if s[:phase] == "answering"
    transmit(picking_payload(s))       if s[:phase] == "picking"
    transmit(revealed_payload(s))      if s[:phase] == "revealed"
    transmit(game_over_payload(s))     if s[:phase] == "game_over"
  end

  def unsubscribed; end

  # TV begins the game.
  def start_game(_data)
    return unless tv?
    players = @room.memberships.where(role: :player).order(:slot).pluck(:slot)
    return transmit({ type: "error", message: "Need #{MIN_PLAYERS}+ players" }) if players.length < MIN_PLAYERS

    s = build_session(players)
    @room.update!(state: :playing)
    RoomChannel.game_starting(@room)
    broadcast_question(s)
  end

  # TV moves from reading -> answering after the read timer.
  def start_answering(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "reading"
    s[:phase] = "answering"
    save_session(s)
    ActionCable.server.broadcast(stream_key, answering_payload(s))
  end

  # Phone (any slot, including spotlight) submits a typed answer.
  def submit(data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "answering"

    slot = params[:slot].to_i
    return unless valid_slot?(s, slot)
    return if s[:submissions].key?(slot.to_s)

    text = data["text"].to_s.strip.slice(0, MAX_ANSWER_LEN)
    return if text.empty?

    s[:submissions][slot.to_s] = text
    save_session(s)

    submitted_count = s[:submissions].size
    expected_count  = active_player_slots(s).length
    ActionCable.server.broadcast(stream_key, {
      type: "player_submitted",
      slot: slot,
      submitted_count: submitted_count,
      expected_count: expected_count
    })

    advance_to_picking(s) if submitted_count >= expected_count
  end

  # TV calls this when the answering timer expires (force-end).
  def end_answering(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "answering"
    advance_to_picking(s)
  end

  # Spotlight picks their favourite non-spotlight submission.
  def pick(data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "picking"
    slot = params[:slot].to_i
    return unless slot == current_spotlight(s)

    picked = data["picked_slot"].to_i
    return unless s[:submissions].key?(picked.to_s)
    return if picked == current_spotlight(s) # can't pick yourself

    s[:picked_slot] = picked
    award_pick_bonus(s, picked)
    do_reveal(s)
  end

  # TV can skip the pick (no favourite) — go straight to reveal.
  def skip_pick(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "picking"
    do_reveal(s)
  end

  # TV advances to next question or ends the game.
  def next_question(_data)
    return unless tv?
    s = get_session
    return unless s

    s[:q_index] += 1
    if s[:q_index] >= s[:order].length
      s[:phase] = "game_over"
      save_session(s)
      ActionCable.server.broadcast(stream_key, game_over_payload(s))
    else
      broadcast_question(s)
    end
  end

  private

  def tv?
    params[:role] == "tv"
  end

  def stream_key
    "spotlight:#{@room.code}"
  end

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@room.code] }
  end

  def save_session(s)
    SESSIONS_MU.synchronize { SESSIONS[@room.code] = s }
  end

  def build_session(player_slots)
    total_questions = player_slots.length * ROUNDS_PER_PLAYER
    question_pool = QUESTIONS.length.times.to_a.shuffle.first(total_questions)
    spotlight_order = (player_slots * ROUNDS_PER_PLAYER).first(total_questions)

    s = {
      phase: "reading",
      q_index: 0,
      order: question_pool,
      spotlight_order: spotlight_order,
      player_slots: player_slots,
      scores: {},
      submissions: {},
      matches: [],
      picked_slot: nil
    }
    save_session(s)
    s
  end

  def current_question(s)
    QUESTIONS[s[:order][s[:q_index]]]
  end

  def current_spotlight(s)
    s[:spotlight_order][s[:q_index]]
  end

  def active_player_slots(s)
    # All players who were in the room when the game started, still present.
    present = @room.memberships.where(role: :player).pluck(:slot)
    s[:player_slots] & present
  end

  def valid_slot?(s, slot)
    active_player_slots(s).include?(slot)
  end

  def player_name(slot)
    @room.memberships.find_by(slot: slot)&.name || "Player #{slot}"
  end

  def normalize(text)
    text.to_s.downcase.strip.gsub(/\s+/, " ")
  end

  def broadcast_question(s)
    s[:phase]        = "reading"
    s[:submissions]  = {}
    s[:matches]      = []
    s[:picked_slot]  = nil
    save_session(s)
    ActionCable.server.broadcast(stream_key, question_payload(s))
  end

  def question_payload(s)
    spot = current_spotlight(s)
    spot_name = player_name(spot)
    raw = current_question(s)[:question]
    rendered = raw.gsub("{spotlight}", spot_name)
    {
      type: "question",
      q_index: s[:q_index],
      total: s[:order].length,
      question: rendered,
      category: current_question(s)[:category],
      spotlight_slot: spot,
      spotlight_name: spot_name,
      spotlight_color: SLOT_COLORS[spot]
    }
  end

  def answering_payload(s)
    {
      type: "answering",
      spotlight_slot: current_spotlight(s),
      spotlight_name: player_name(current_spotlight(s)),
      submitted_count: s[:submissions].size,
      expected_count: active_player_slots(s).length
    }
  end

  def advance_to_picking(s)
    spot = current_spotlight(s)
    spot_answer = s[:submissions][spot.to_s].to_s
    spot_norm = normalize(spot_answer)

    matches = s[:submissions].each_with_object([]) do |(slot_s, text), acc|
      slot = slot_s.to_i
      next if slot == spot
      next if spot_norm.empty? || normalize(text) != spot_norm
      acc << slot
    end
    s[:matches] = matches

    matches.each do |slot|
      s[:scores][slot.to_s] = (s[:scores][slot.to_s] || 0) + 2
    end

    pickable = s[:submissions].keys.map(&:to_i).reject { |sl| sl == spot }
    if pickable.empty? || spot_answer.empty?
      save_session(s)
      do_reveal(s)
    else
      s[:phase] = "picking"
      save_session(s)
      ActionCable.server.broadcast(stream_key, picking_payload(s))
    end
  end

  def picking_payload(s)
    spot = current_spotlight(s)
    spot_answer = s[:submissions][spot.to_s].to_s
    submissions = s[:submissions].map do |slot_s, text|
      slot = slot_s.to_i
      {
        slot: slot,
        name: player_name(slot),
        color: SLOT_COLORS[slot],
        text: text,
        is_spotlight: slot == spot,
        matched: s[:matches].include?(slot)
      }
    end
    {
      type: "picking",
      spotlight_slot: spot,
      spotlight_name: player_name(spot),
      spotlight_answer: spot_answer,
      submissions: submissions
    }
  end

  def award_pick_bonus(s, picked_slot)
    s[:scores][picked_slot.to_s] = (s[:scores][picked_slot.to_s] || 0) + 3
    save_session(s)
  end

  def do_reveal(s)
    s[:phase] = "revealed"
    save_session(s)
    ActionCable.server.broadcast(stream_key, revealed_payload(s))
  end

  def revealed_payload(s)
    spot = current_spotlight(s)
    submissions = s[:submissions].map do |slot_s, text|
      slot = slot_s.to_i
      {
        slot: slot,
        name: player_name(slot),
        color: SLOT_COLORS[slot],
        text: text,
        is_spotlight: slot == spot,
        matched: s[:matches].include?(slot),
        picked: slot == s[:picked_slot]
      }
    end
    {
      type: "revealed",
      spotlight_slot: spot,
      spotlight_name: player_name(spot),
      spotlight_answer: s[:submissions][spot.to_s].to_s,
      picked_slot: s[:picked_slot],
      submissions: submissions,
      scores: s[:scores]
    }
  end

  def game_over_payload(s)
    named_scores = s[:scores].map do |slot_s, pts|
      slot = slot_s.to_i
      { slot: slot, name: player_name(slot), color: SLOT_COLORS[slot], points: pts }
    end.sort_by { |e| -e[:points] }
    @room.memberships.where(role: :player).each do |m|
      next if s[:scores].key?(m.slot.to_s)
      named_scores << { slot: m.slot, name: m.name, color: SLOT_COLORS[m.slot], points: 0 }
    end
    { type: "game_over", scores: named_scores }
  end
end
