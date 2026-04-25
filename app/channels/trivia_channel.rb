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
    return unless s

    case s[:phase]
    when "reading"
      q = current_question(s)
      transmit({ type: "question", q_index: s[:q_index], total: s[:order].length,
                 question: q[:question], category: q[:category] })
    when "answering"
      q = current_question(s)
      transmit({ type: "question", q_index: s[:q_index], total: s[:order].length,
                 question: q[:question], category: q[:category] })
      transmit({ type: "answering", options: q[:options] })
    else
      transmit({ type: "sync", phase: s[:phase] })
    end
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

  # TV calls this (via timer) after the reading phase ends
  def start_answering(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "reading"
    s[:phase] = "answering"
    s[:answers] = {}
    save_session(s)
    q = current_question(s)
    ActionCable.server.broadcast(stream_key, { type: "answering", options: q[:options] })
  end

  # Phone submits an answer during answering phase
  def answer(data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "answering"
    slot = params[:slot].to_i
    return if s[:answers].key?(slot.to_s)

    chosen = data["index"].to_i
    correct = chosen == current_question(s)[:answer]
    s[:answers][slot.to_s] = { index: chosen, correct: correct }
    s[:scores][slot.to_s] = (s[:scores][slot.to_s] || 0) + 1 if correct
    save_session(s)

    player_count = @room.memberships.where(role: :player).count
    ActionCable.server.broadcast(stream_key, {
      type: "player_answered",
      slot: slot,
      answered_count: s[:answers].size,
      total_players: player_count
    })

    do_reveal(s) if s[:answers].size >= player_count
  end

  # TV calls this to force-reveal (timer expired or skip)
  def reveal(_data)
    return unless tv?
    s = get_session
    return unless s && s[:phase] == "answering"
    do_reveal(s)
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
      broadcast_question(s)
    end
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
    s = { phase: "reading", q_index: 0, order: order, scores: {}, answers: {} }
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
    s[:phase] = "reading"
    s[:answers] = {}
    save_session(s)
    ActionCable.server.broadcast(stream_key, {
      type: "question",
      q_index: s[:q_index],
      total: s[:order].length,
      question: q[:question],
      category: q[:category]
    })
  end

  def do_reveal(s)
    s[:phase] = "revealed"
    save_session(s)
    q = current_question(s)
    results = s[:answers].map do |slot_s, ans|
      slot = slot_s.to_i
      { slot: slot, name: player_name(slot), color: SLOT_COLORS[slot], correct: ans[:correct], index: ans[:index] }
    end
    ActionCable.server.broadcast(stream_key, {
      type: "revealed",
      correct_index: q[:answer],
      correct_answer: q[:options][q[:answer]],
      scores: s[:scores],
      results: results
    })
  end

  def broadcast_game_over(s)
    named_scores = s[:scores].map do |slot_s, pts|
      slot = slot_s.to_i
      { slot: slot, name: player_name(slot), color: SLOT_COLORS[slot], points: pts }
    end.sort_by { |e| -e[:points] }
    ActionCable.server.broadcast(stream_key, { type: "game_over", scores: named_scores })
  end
end
