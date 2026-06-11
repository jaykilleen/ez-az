class GoldenGoalChannel < ApplicationCable::Channel
  # Real-time penalty shootout. The TV is authoritative: it runs the match,
  # decides goal/save and renders. Phones only send their secret picks.
  # Mirrors SnakePitChannel (ADR 006), with one twist: a locked pick must stay
  # hidden from the other phones, so picks are relayed on a TV-only private
  # stream (ADR 006 section 5) instead of the public one.
  SESSIONS    = {}
  SESSIONS_MU = Mutex.new

  KINDS   = %w[shot dive].freeze
  AIMS    = %w[left centre right].freeze
  HEIGHTS = %w[high low].freeze

  # Public broadcasts the TV is allowed to push to every phone. Nothing
  # secret travels here -- picks only ever go the other way, phone -> TV.
  TV_EVENTS = %w[round_setup reveal scoreboard].freeze

  def subscribed
    code = params[:code].to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return reject if code.blank? || code.length < 4

    @code = code
    @role = params[:role].to_s
    stream_from "golden_goal:#{@code}"
    # TV-only private stream -- secret picks land here and nowhere else.
    stream_from "golden_goal:#{@code}:tv" if @role == "tv"

    SESSIONS_MU.synchronize { SESSIONS[@code] ||= new_session } if @role == "tv"

    s = get_session
    transmit({ type: "state", phase: s&.dig(:phase) || "lobby", players: player_list(s) }) if s
  end

  def unsubscribed
    return unless @role == "phone" && !@slot.nil?

    s = get_session
    return unless s && s[:phase] == "lobby"

    SESSIONS_MU.synchronize { s[:players].delete(@slot) }
    ActionCable.server.broadcast("golden_goal:#{@code}", {
      type: "lobby_update", players: player_list(s)
    })
  end

  # Phone: enter name, get assigned a slot (0-3)
  def join(data)
    return if @role == "tv"

    s = get_session
    return transmit({ type: "join_error", message: "Game not found" }) unless s
    return transmit({ type: "join_error", message: "Game already started" }) unless s[:phase] == "lobby"

    name = data["name"].to_s.strip.upcase[0, 12]
    return transmit({ type: "join_error", message: "Enter a name" }) if name.blank?

    slot = nil
    SESSIONS_MU.synchronize do
      (0..3).each do |i|
        next if s[:players].key?(i)
        s[:players][i] = { name: name }
        @slot = i
        slot = i
        break
      end
    end

    return transmit({ type: "join_error", message: "Game is full (4 players)" }) if slot.nil?

    transmit({ type: "joined", slot: slot, name: name })
    ActionCable.server.broadcast("golden_goal:#{@code}", {
      type: "lobby_update", players: player_list(s)
    })
  end

  # Phone: lock a secret pick. Relayed on the TV-only stream so the other
  # phones never see it.
  # data: { kind: 'shot' | 'dive', aim: 'left'|'centre'|'right', height: 'high'|'low' }
  def pick(data)
    return unless @role == "phone" && !@slot.nil?

    s = get_session
    return unless s && s[:phase] == "playing"

    kind   = data["kind"].to_s
    aim    = data["aim"].to_s
    height = data["height"].to_s
    return unless KINDS.include?(kind) && AIMS.include?(aim) && HEIGHTS.include?(height)

    ActionCable.server.broadcast("golden_goal:#{@code}:tv", {
      type: "pick", slot: @slot, kind: kind, aim: aim, height: height
    })
  end

  # TV: push public round state to every phone (whitelisted event types only).
  # The match itself is orchestrated on the TV; the channel just relays.
  def tv_event(data)
    return unless @role == "tv"

    event = data["event"].to_s
    return unless TV_EVENTS.include?(event)

    s = get_session
    return unless s

    ActionCable.server.broadcast("golden_goal:#{@code}",
      (data["payload"] || {}).merge("type" => event))
  end

  # TV: start the match
  def start_game(_data)
    return unless @role == "tv"

    s = get_session
    return unless s && s[:phase] == "lobby"

    SESSIONS_MU.synchronize { s[:phase] = "playing" }
    ActionCable.server.broadcast("golden_goal:#{@code}", { type: "game_started" })
  end

  # TV: report final results (resets session to lobby for a rematch)
  def game_ended(data)
    return unless @role == "tv"

    s = get_session
    return unless s

    SESSIONS_MU.synchronize { s[:phase] = "lobby" }
    ActionCable.server.broadcast("golden_goal:#{@code}", {
      type: "game_over", results: data["results"] || []
    })
  end

  private

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@code] }
  end

  def new_session
    { phase: "lobby", players: {} }
  end

  def player_list(s)
    return [] unless s
    s[:players].map { |slot, p| { slot: slot, name: p[:name] } }
  end
end
