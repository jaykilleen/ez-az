class SnakePitChannel < ApplicationCable::Channel
  # Real-time 4-player snake arena. The TV is authoritative: it runs the
  # simulation and renders. Phones only send a desired direction; the channel
  # relays it on the public stream. Session / slot / host / lifecycle
  # plumbing (join, leave, host start, abort, TTL sweep) comes from
  # ArcadeSession -- the shared Phone Contract implementation.
  include ArcadeSession
  arcade_prefix "snake_pit"

  DIRS = %w[up down left right].freeze

  # Phone: steer the snake
  # data: { dir: 'up' | 'down' | 'left' | 'right' }
  def input(data)
    return unless phone? && !@slot.nil?

    s = session
    return unless s && s[:phase] == "playing"

    dir = data["dir"].to_s
    return unless DIRS.include?(dir)

    broadcast_game(type: "input", slot: @slot, dir: dir)
  end

  private

  # Stop the snake turning once the phone drops or leaves mid-match; the TV
  # bot-fills on player_left.
  def arcade_player_disconnected(slot)
    broadcast_game(type: "input", slot: slot, dir: "none")
  end
end
