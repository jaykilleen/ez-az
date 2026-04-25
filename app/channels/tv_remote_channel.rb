class TvRemoteChannel < ApplicationCable::Channel
  ALLOWED_DIRS   = %w[left right up down select back action].freeze
  ALLOWED_TYPES  = %w[press release].freeze
  ALLOWED_STATES = %w[shelf lobby game].freeze
  SLOT_COLORS    = { 1 => "#ff4757", 2 => "#3742fa", 3 => "#ffa502", 4 => "#2ed573" }.freeze

  # In-memory state per token so late-connecting phones get the current TV state immediately
  STATES       = {}
  STATES_MUTEX = Mutex.new

  def subscribed
    token = clean_token
    return reject if token.blank?
    stream_from "tv_remote:#{token}"
    STATES_MUTEX.synchronize { transmit(STATES[token]) if STATES[token] }
  end

  # Phone→TV: D-pad press/release
  def navigate(data)
    dir      = data["direction"].to_s
    nav_type = data["nav_type"].to_s
    return unless ALLOWED_DIRS.include?(dir)
    return unless nav_type.blank? || ALLOWED_TYPES.include?(nav_type)
    phone_id = data["phone_id"].to_s.gsub(/[^a-zA-Z0-9]/, "")[0, 16]
    ActionCable.server.broadcast("tv_remote:#{clean_token}", {
      type: "navigate", direction: dir,
      nav_type: nav_type.presence || "press",
      phone_id: phone_id.presence
    })
  end

  # TV→phones: broadcast current TV state so phones know what to show
  def set_state(data)
    state = data["state"].to_s
    return unless ALLOWED_STATES.include?(state)
    payload = { type: "tv_state", state: state }
    payload[:room_code]  = data["room_code"].to_s.upcase.slice(0, 8)  if data["room_code"].present?
    payload[:game_title] = data["game_title"].to_s.slice(0, 40)       if data["game_title"].present?
    STATES_MUTEX.synchronize { STATES[clean_token] = payload }
    ActionCable.server.broadcast("tv_remote:#{clean_token}", payload)
  end

  # Phone joins a trivia room in-page — no browser navigation required
  def join_room(data)
    code = data["code"].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 6]
    name = data["name"].to_s.strip.upcase.slice(0, 12)
    return transmit({ type: "join_error", message: "Enter your name" }) if name.blank?

    room = Room.active.find_by(code: code)
    return transmit({ type: "join_error", message: "Room not found" }) unless room
    return transmit({ type: "join_error", message: "Room is full" })   if room.full?

    slot = room.next_available_slot
    return transmit({ type: "join_error", message: "No slots available" }) unless slot

    membership = room.memberships.create!(
      name:       name,
      slot:       slot,
      role:       :player,
      session_id: SecureRandom.hex(16)
    )
    RoomChannel.member_joined(room, membership)

    members = room.memberships.reload.map(&:display)
    transmit({ type: "joined", slot: slot, name: name, color: SLOT_COLORS[slot], code: code, members: members })
  end

  private

  def clean_token
    params[:token].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
  end
end
