# Phones send inputs on this channel; the TV streams from the same room
# input feed and dispatches them as keyboard events on its end.
#
# Subscription params:
#   { code: "ABCD" }            -> TV subscription: streams only, does not send
#   { code: "ABCD", slot: 1..4 } -> phone subscription: sends via #input
#
# Client payload for #input:
#   { type: "keydown" | "keyup", input: "up" | "down" | "left" | "right"
#                                      | "primary" | "secondary" | "pause" }
#
# Broadcast payload (to TV subscribers):
#   { slot: 1, type: "keydown", input: "up" }
class ControllerChannel < ApplicationCable::Channel
  INPUT_STREAM_SUFFIX  = ":input"
  ALLOWED_INPUT_TYPES  = %w[keydown keyup].freeze
  ALLOWED_INPUT_NAMES  = %w[up down left right primary secondary pause].freeze

  def subscribed
    room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless room

    if phone?
      return reject unless valid_slot?(room)
      # Phones are senders. We don't stream_from anything — they only
      # perform #input. This keeps phones from receiving echoes of their
      # own events or seeing other players' inputs, which is wasteful
      # bandwidth at best and risks bugs at worst.
    else
      stream_from input_stream(room)
    end
  end

  def input(data)
    room = Room.active.find_by(code: params[:code].to_s.upcase)
    return unless room && phone? && valid_slot?(room)

    type  = data["type"].to_s
    name  = data["input"].to_s
    return unless ALLOWED_INPUT_TYPES.include?(type)
    return unless ALLOWED_INPUT_NAMES.include?(name)

    ActionCable.server.broadcast(
      input_stream(room),
      { slot: slot, type: type, input: name }
    )
  end

  private

  def phone?
    params[:slot].present?
  end

  def slot
    params[:slot].to_i
  end

  def valid_slot?(room)
    (1..Room::MAX_PLAYERS).cover?(slot) && room.memberships.exists?(slot: slot)
  end

  def input_stream(room)
    "#{room.channel_name}#{INPUT_STREAM_SUFFIX}"
  end
end
