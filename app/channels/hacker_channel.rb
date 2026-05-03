class HackerChannel < ApplicationCable::Channel
  SESSIONS = {}
  SESSIONS_MU = Mutex.new

  SLOT_COLORS = {
    1 => "#ff4757",
    2 => "#3742fa",
    3 => "#ffa502",
    4 => "#2ed573"
  }.freeze

  MIN_PLAYERS = 1

  DIGITS = ("0".."9").to_a.freeze
  UPPER  = ("A".."Z").to_a.freeze
  LOWER  = ("a".."z").to_a.freeze
  SYMBS  = %w[! @ # $ % & * ?].freeze

  DIFFICULTIES = {
    "easy" => {
      label: "EASY",
      length: 4,
      alphabet: DIGITS,
      real_world_crack: "1 second",
      hint: "4 digits. Like a phone PIN."
    },
    "medium" => {
      label: "MEDIUM",
      length: 6,
      alphabet: DIGITS,
      real_world_crack: "17 minutes",
      hint: "6 digits. Already a million combos."
    },
    "hard" => {
      label: "HARD",
      length: 8,
      alphabet: DIGITS + UPPER,
      real_world_crack: "9 days",
      hint: "8 chars, letters + numbers. Real brute force."
    },
    "impossible" => {
      label: "IMPOSSIBLE",
      length: 12,
      alphabet: DIGITS + UPPER + LOWER + SYMBS,
      real_world_crack: "200 years",
      hint: "12 chars with symbols. This is what good passwords look like."
    }
  }.freeze

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key

    s = get_session
    return unless s

    case s[:phase]
    when "playing"
      transmit(playing_payload(s))
    when "won"
      transmit(won_payload(s))
    end
  end

  def unsubscribed; end

  def start_game(data)
    return unless tv?
    difficulty = data["difficulty"].to_s
    return transmit({ type: "error", message: "Pick a difficulty" }) unless DIFFICULTIES.key?(difficulty)

    players = @room.memberships.where(role: :player).order(:slot).pluck(:slot)
    return transmit({ type: "error", message: "Need #{MIN_PLAYERS}+ player" }) if players.length < MIN_PLAYERS

    s = build_session(players, difficulty)
    @room.update!(state: :playing)
    RoomChannel.game_starting(@room)
    ActionCable.server.broadcast(stream_key, playing_payload(s))
  end

  # Phone submits a guess for one slot.
  def attempt(data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "playing"

    slot_index = data["slot_index"].to_i
    char       = data["char"].to_s
    return unless slot_index >= 0 && slot_index < s[:length]
    return unless s[:alphabet].include?(char)

    # Already cracked — ignore (don't increment attempts for solved slots).
    return if s[:revealed][slot_index]

    s[:attempts] += 1
    player_slot = params[:slot].to_i
    correct = (s[:code][slot_index] == char)

    if correct
      s[:revealed][slot_index] = true
      save_session(s)
      ActionCable.server.broadcast(stream_key, {
        type:           "slot_solved",
        slot_index:     slot_index,
        char:           char,
        attempts:       s[:attempts],
        revealed:       s[:revealed],
        revealed_count: s[:revealed].count(true),
        cracked_by:     player_slot,
        cracked_color:  SLOT_COLORS[player_slot]
      })

      if s[:revealed].all?
        s[:phase]       = "won"
        s[:finished_at] = Time.current.to_f
        save_session(s)
        record_score(s)
        ActionCable.server.broadcast(stream_key, won_payload(s))
      end
    else
      save_session(s)
      ActionCable.server.broadcast(stream_key, {
        type:        "miss",
        slot_index:  slot_index,
        char:        char,
        attempts:    s[:attempts],
        missed_by:   player_slot,
        missed_color: SLOT_COLORS[player_slot]
      })
    end
  end

  # TV resets back to the difficulty picker for another round.
  def reset(_data)
    return unless tv?
    SESSIONS_MU.synchronize { SESSIONS.delete(@room.code) }
    @room.update!(state: :lobby) if @room.state == "playing"
    ActionCable.server.broadcast(stream_key, { type: "reset" })
  end

  private

  def tv?
    params[:role] == "tv"
  end

  def stream_key
    "hacker:#{@room.code}"
  end

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@room.code] }
  end

  def save_session(s)
    SESSIONS_MU.synchronize { SESSIONS[@room.code] = s }
  end

  def build_session(player_slots, difficulty)
    cfg = DIFFICULTIES[difficulty]
    code = Array.new(cfg[:length]) { cfg[:alphabet].sample }

    s = {
      phase:            "playing",
      difficulty:       difficulty,
      label:            cfg[:label],
      hint:             cfg[:hint],
      real_world_crack: cfg[:real_world_crack],
      length:           cfg[:length],
      alphabet:         cfg[:alphabet],
      code:             code,
      revealed:         Array.new(cfg[:length], false),
      attempts:         0,
      player_slots:     player_slots,
      started_at:       Time.current.to_f,
      finished_at:      nil
    }
    save_session(s)
    s
  end

  def playing_payload(s)
    {
      type:             "playing",
      difficulty:       s[:difficulty],
      label:            s[:label],
      hint:             s[:hint],
      real_world_crack: s[:real_world_crack],
      length:           s[:length],
      alphabet:         s[:alphabet],
      revealed:         s[:revealed],
      revealed_chars:   s[:revealed].each_with_index.map { |r, i| r ? s[:code][i] : nil },
      attempts:         s[:attempts],
      started_at_ms:    (s[:started_at] * 1000).to_i
    }
  end

  def won_payload(s)
    elapsed_ms = ((s[:finished_at] - s[:started_at]) * 1000).to_i
    {
      type:             "won",
      difficulty:       s[:difficulty],
      label:            s[:label],
      real_world_crack: s[:real_world_crack],
      code:             s[:code],
      attempts:         s[:attempts],
      elapsed_ms:       elapsed_ms,
      players:          s[:player_slots].map do |slot|
        {
          slot:  slot,
          name:  player_name(slot),
          color: SLOT_COLORS[slot]
        }
      end
    }
  end

  def player_name(slot)
    @room.memberships.find_by(slot: slot)&.name || "Player #{slot}"
  end

  # Persist a leaderboard entry: team time in milliseconds (asc — fastest wins).
  # Entry name is the team — comma-joined player names, capped at 12 chars.
  def record_score(s)
    elapsed_ms = ((s[:finished_at] - s[:started_at]) * 1000).to_i
    return if elapsed_ms <= 0

    names = s[:player_slots].map { |slot| player_name(slot) }.join("+")
    Score.create(game: "hacker-pro", value: elapsed_ms, name: names)
  rescue ActiveRecord::RecordInvalid
    # Score validation failure shouldn't break the game.
  end
end
