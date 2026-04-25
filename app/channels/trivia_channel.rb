class TriviaChannel < ApplicationCable::Channel
  SESSIONS = {}
  SESSIONS_MU = Mutex.new

  QUESTIONS = YAML.load_file(
    Rails.root.join("db/questions/trivia.yml"),
    permitted_classes: [], aliases: true
  ).map(&:symbolize_keys).map do |q|
    q.merge(options: q[:options])
  end.freeze

  SLOT_COLORS = {
    1 => "#ff4757",
    2 => "#3742fa",
    3 => "#ffa502",
    4 => "#2ed573"
  }.freeze

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key
    s = get_session
    transmit({ type: "sync", phase: s ? s[:phase] : "lobby" }) if s
  end

  def unsubscribed; end

  # TV calls this to begin the game
  def start_game(_data)
    return unless tv?

    s = build_session
    @room.update!(state: :playing)
    RoomChannel.game_starting(@room)
    broadcast_question(s)
  end

  # TV calls this to advance to the next question (or end the game)
  def next_question(_data)
    return unless tv?

    s = get_session
    return unless s

    s[:q_index] += 1

    if s[:q_index] >= s[:order].length
      s[:phase] = "game_over"
      save_session(s)
      broadcast_game_over(s)
    else
      s[:phase] = "question"
      s[:buzzed_slot] = nil
      s[:locked_slots] = []
      save_session(s)
      broadcast_question(s)
    end
  end

  # TV calls this to reveal the answer without a correct buzz (timer expired / skip)
  def reveal(_data)
    return unless tv?

    s = get_session
    return unless s

    s[:phase] = "revealed"
    s[:buzzed_slot] = nil
    save_session(s)

    ActionCable.server.broadcast(stream_key, {
      type: "revealed",
      correct_index: current_question(s)[:answer],
      scores: s[:scores]
    })
  end

  # Phone calls this to buzz in
  def buzz(_data)
    return if tv?

    s = get_session
    return unless s && s[:phase] == "question"

    slot = params[:slot].to_i
    return if s[:buzzed_slot] || s[:locked_slots].include?(slot)

    s[:buzzed_slot] = slot
    s[:phase] = "buzzed"
    save_session(s)

    name = player_name(slot)
    ActionCable.server.broadcast(stream_key, {
      type: "buzzed",
      slot: slot,
      name: name,
      color: SLOT_COLORS[slot],
      options: current_question(s)[:options]
    })
  end

  # Phone calls this after buzzing to select an answer
  def answer(data)
    return if tv?

    s = get_session
    return unless s && s[:phase] == "buzzed"

    slot = params[:slot].to_i
    return unless s[:buzzed_slot] == slot

    chosen = data["index"].to_i
    correct = chosen == current_question(s)[:answer]

    if correct
      s[:scores][slot.to_s] = (s[:scores][slot.to_s] || 0) + 1
      s[:phase] = "revealed"
      s[:buzzed_slot] = nil
    else
      s[:locked_slots] << slot
      s[:buzzed_slot] = nil
      s[:phase] = "question"
    end
    save_session(s)

    ActionCable.server.broadcast(stream_key, {
      type: "answered",
      slot: slot,
      name: player_name(slot),
      color: SLOT_COLORS[slot],
      correct: correct,
      correct_index: current_question(s)[:answer],
      scores: s[:scores]
    })
  end

  private

  def tv?
    params[:role] == "tv"
  end

  def stream_key
    "trivia:#{@room.code}"
  end

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@room.code] }
  end

  def save_session(s)
    SESSIONS_MU.synchronize { SESSIONS[@room.code] = s }
  end

  def build_session
    order = QUESTIONS.length.times.to_a.shuffle.first([ QUESTIONS.length, 15 ].min)
    s = {
      phase: "question",
      q_index: 0,
      order: order,
      scores: {},
      buzzed_slot: nil,
      locked_slots: []
    }
    save_session(s)
    s
  end

  def current_question(s)
    QUESTIONS[s[:order][s[:q_index]]]
  end

  def player_name(slot)
    @room.memberships.find_by(slot: slot)&.name || "Player #{slot}"
  end

  def broadcast_question(s)
    q = current_question(s)
    ActionCable.server.broadcast(stream_key, {
      type: "question",
      q_index: s[:q_index],
      total: s[:order].length,
      question: q[:question],
      options: q[:options],
      category: q[:category],
      answer: q[:answer]
    })
  end

  def broadcast_game_over(s)
    named_scores = s[:scores].map do |slot_s, pts|
      slot = slot_s.to_i
      { slot: slot, name: player_name(slot), color: SLOT_COLORS[slot], points: pts }
    end.sort_by { |e| -e[:points] }

    ActionCable.server.broadcast(stream_key, {
      type: "game_over",
      scores: named_scores
    })
  end
end
