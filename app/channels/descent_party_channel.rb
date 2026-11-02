class DescentPartyChannel < ApplicationCable::Channel
  # TV is authoritative — it renders 4 quadrants and tracks all maze state.
  # Phones are D-pad controllers: touchstart → press, touchend → release.
  # ArcadeSession owns lobby / slot / host / lifecycle (ADR 010).
  # All data-receiving actions use required params (ADR 021, arity rule).
  include ArcadeSession
  arcade_prefix "descent_party"

  ALLOWED_KEYS = %w[ArrowUp ArrowDown ArrowLeft ArrowRight ShiftLeft].freeze
  FLOOR_SYNC_OPTIONS    = %w[independent all-advance].freeze
  WIN_CONDITION_OPTIONS = %w[race time-limit].freeze

  # TV or host phone: start the game and broadcast chosen options to all subscribers.
  # Overrides ArcadeSession#start_game so we can include floor_sync / win_condition.
  def start_game(data)
    s = session
    return unless s && s[:phase] == "lobby"
    return unless tv? || host?

    floor_sync    = FLOOR_SYNC_OPTIONS.include?(data["floor_sync"].to_s)    ? data["floor_sync"]    : "independent"
    win_condition = WIN_CONDITION_OPTIONS.include?(data["win_condition"].to_s) ? data["win_condition"] : "race"

    sessions_mu.synchronize { s[:phase] = "playing" }
    broadcast_game(type: "game_started", floor_sync: floor_sync, win_condition: win_condition)
  end

  # Phone: key held down (touchstart on D-pad segment or sprint button)
  def press(data)
    return unless phone? && !@slot.nil?
    s = session
    return unless s && s[:phase] == "playing"
    key = data["key"].to_s
    return unless ALLOWED_KEYS.include?(key)
    broadcast_game(type: "press", slot: @slot, key: key)
  end

  # Phone: key released (touchend / touchcancel)
  def release(data)
    return unless phone? && !@slot.nil?
    s = session
    return unless s && s[:phase] == "playing"
    key = data["key"].to_s
    return unless ALLOWED_KEYS.include?(key)
    broadcast_game(type: "release", slot: @slot, key: key)
  end

  private

  # When a phone drops mid-match, release all its held keys so the avatar
  # doesn't keep walking into a wall.
  def arcade_player_disconnected(slot)
    broadcast_game(type: "all_keys_up", slot: slot)
  end
end
