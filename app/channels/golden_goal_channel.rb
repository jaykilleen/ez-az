class GoldenGoalChannel < ApplicationCable::Channel
  # Real-time penalty shootout. The TV is authoritative: it runs the match,
  # decides goal/save and renders. Phones only send their secret picks.
  # Session / slot / host / lifecycle plumbing (join, leave, host start,
  # abort, TTL sweep) comes from ArcadeSession -- the shared Phone Contract
  # implementation. Golden Goal's twist: a locked pick must stay hidden from
  # the other phones, so picks are relayed on a TV-only private stream
  # (ADR 006 section 5) layered on via arcade_after_subscribe.
  include ArcadeSession
  arcade_prefix "golden_goal"

  KINDS   = %w[shot dive].freeze
  AIMS    = %w[left centre right].freeze
  HEIGHTS = %w[high low].freeze

  # Public broadcasts the TV is allowed to push to every phone. Nothing
  # secret travels here -- picks only ever go the other way, phone -> TV.
  TV_EVENTS = %w[round_setup reveal scoreboard].freeze

  # Phone: lock a secret pick. Relayed on the TV-only stream so the other
  # phones never see it.
  # data: { kind: 'shot' | 'dive', aim: 'left'|'centre'|'right', height: 'high'|'low' }
  def pick(data)
    return unless phone? && !@slot.nil?

    s = session
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
    return unless tv?

    event = data["event"].to_s
    return unless TV_EVENTS.include?(event)

    s = session
    return unless s

    broadcast_game((data["payload"] || {}).merge("type" => event))
  end

  private

  # TV-only private stream -- secret picks land here and nowhere else.
  def arcade_after_subscribe
    stream_from "golden_goal:#{@code}:tv" if tv?
  end
end
