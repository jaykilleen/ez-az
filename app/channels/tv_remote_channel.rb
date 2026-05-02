class TvRemoteChannel < ApplicationCable::Channel
  ALLOWED_DIRS   = %w[left right up down select back action].freeze
  ALLOWED_TYPES  = %w[press release].freeze
  ALLOWED_STATES = %w[shelf lobby game watch].freeze
  SLOT_COLORS    = { 1 => "#ff4757", 2 => "#3742fa", 3 => "#ffa502", 4 => "#2ed573" }.freeze

  STATES       = {}
  STATES_MUTEX = Mutex.new

  def subscribed
    token = clean_token
    return reject if token.blank?

    @current_room = Room.active.find_by(tv_token: token)
    return reject unless @current_room

    stream_from "tv_remote:#{token}"
    @device_token = clean_device_token
    @slot_claimed = false

    if @current_room && @device_token.present?
      membership = @current_room.memberships.find_by(device_token: @device_token)
      if membership
        membership.update_column(:connected, true)
        transmit({
          type:       "rejoined",
          slot:       membership.slot,
          name:       membership.name,
          color:      SLOT_COLORS[membership.slot],
          phone_id:   @device_token,
          code:       @current_room.code,
          game_slug:  @current_room.game_slug
        })
        @slot_claimed = true
      end
    end

    STATES_MUTEX.synchronize { transmit(STATES[token]) if STATES[token] }
  end

  def unsubscribed
    if @current_room && @device_token.present?
      @current_room.memberships
                   .where(device_token: @device_token)
                   .update_all(connected: false)
    end
  end

  def navigate(data)
    dir      = data["direction"].to_s
    nav_type = data["nav_type"].to_s
    return unless ALLOWED_DIRS.include?(dir)
    return unless nav_type.blank? || ALLOWED_TYPES.include?(nav_type)

    phone_id = data["phone_id"].to_s.gsub(/[^a-zA-Z0-9]/, "")[0, 64]

    if @current_room && phone_id.present? && !@slot_claimed
      ensure_membership_for(phone_id)
    end

    ActionCable.server.broadcast("tv_remote:#{clean_token}", {
      type:      "navigate",
      direction: dir,
      nav_type:  nav_type.presence || "press",
      phone_id:  phone_id.presence
    })
  end

  def set_state(data)
    state = data["state"].to_s
    return unless ALLOWED_STATES.include?(state)
    payload = { type: "tv_state", state: state }
    payload[:room_code]  = data["room_code"].to_s.upcase.slice(0, 8)  if data["room_code"].present?
    payload[:game_title] = data["game_title"].to_s.slice(0, 40)       if data["game_title"].present?
    STATES_MUTEX.synchronize { STATES[clean_token] = payload }
    ActionCable.server.broadcast("tv_remote:#{clean_token}", payload)
  end

  def leave_room(_data = {})
    return unless @current_room && @device_token.present?

    membership = @current_room.memberships.find_by(device_token: @device_token)
    return unless membership

    RoomChannel.member_left(@current_room, membership)
    membership.destroy
    @slot_claimed = false
    transmit({ type: "left" })
  end

  def join_room(data)
    code = data["code"].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 6]
    name = data["name"].to_s.strip.upcase.slice(0, 12)
    return transmit({ type: "join_error", message: "Enter your name" }) if name.blank?

    room = Room.active.find_by(code: code)
    return transmit({ type: "join_error", message: "Room not found" }) unless room
    return transmit({ type: "join_error", message: "Room is full" })   if room.full?

    slot = room.next_available_slot
    return transmit({ type: "join_error", message: "No slots available" }) unless slot

    player = @device_token.present? ? Player.find_by(device_token: @device_token) : nil

    membership = room.memberships.create!(
      name:       name,
      slot:       slot,
      role:       :player,
      device_token: @device_token.presence,
      player:     player,
      session_id: SecureRandom.hex(16)
    )
    RoomChannel.member_joined(room, membership)

    members = room.memberships.reload.map(&:display)
    transmit({
      type: "joined", slot: slot, name: name, color: SLOT_COLORS[slot],
      code: code, game_slug: room.game_slug, members: members
    })
  end

  private

  def clean_token
    params[:token].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
  end

  def clean_device_token
    params[:device_token].to_s.gsub(/[^a-zA-Z0-9]/, "")[0, 64]
  end

  def ensure_membership_for(phone_id)
    @slot_claimed = true
    return if @current_room.memberships.exists?(device_token: phone_id)

    player = Player.find_by(device_token: phone_id)

    (1..Room::MAX_PLAYERS).each do |slot|
      next if @current_room.memberships.exists?(slot: slot)
      name = player&.username || "P#{slot}"
      begin
        membership = @current_room.memberships.create!(
          name:         name,
          slot:         slot,
          role:         :player,
          device_token: phone_id,
          player:       player,
          session_id:   SecureRandom.hex(16)
        )
        ActionCable.server.broadcast("tv_remote:#{clean_token}", {
          type:     "slot_assigned",
          slot:     membership.slot,
          name:     membership.name,
          color:    SLOT_COLORS[membership.slot],
          phone_id: phone_id
        })
        return
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        next
      end
    end
  end
end
