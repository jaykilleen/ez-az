# ActionCable channel for a single room. Both the TV (lobby view) and
# phones (controllers) subscribe to the same stream so everyone sees
# joins, leaves, and game-state changes in real time.
#
# Subscribing requires a valid room code. Unknown codes are rejected
# during #subscribed so the client sees a subscription rejection.
class RoomChannel < ApplicationCable::Channel
  def subscribed
    room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless room

    stream_from room.channel_name
  end

  # Broadcast helpers for controllers to call. Keeping the channel
  # responsible for the payload shape means controllers just call these.
  class << self
    def member_joined(room, membership)
      ActionCable.server.broadcast(
        room.channel_name,
        { type: "member_joined", member: membership.display, members: current_members(room) }
      )
    end

    def member_left(room, membership)
      ActionCable.server.broadcast(
        room.channel_name,
        { type: "member_left", slot: membership.slot, members: current_members(room) }
      )
    end

    def game_starting(room)
      ActionCable.server.broadcast(
        room.channel_name,
        { type: "game_starting", game_slug: room.game_slug }
      )
    end

    private

    def current_members(room)
      room.memberships.reload.map(&:display)
    end
  end
end
