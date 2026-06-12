# Shared session / slot / host / lifecycle plumbing for the real-time TV
# arcade channels (Snake Pit Royale, Golden Goal, ...). The including channel
# keeps its game-specific state and actions (steering input, secret picks);
# this concern owns everything the Phone Contract (build-game Phase 4C)
# needs from the server:
#
#   join        phone takes a slot in the lobby; the first joiner is host
#   leave       valid in EVERY phase (clause 4) -- frees the slot, promotes
#               a new host, tells the TV so it can bot-fill mid-match
#   start_game  allowed from the TV or the host phone (clause 3)
#   game_ended  TV reports results; phase returns to lobby, slots are kept
#               so a rematch keeps the party together (clause 6)
#   abort       TV quits mid-match (clause 5); phase resets to lobby and
#               every phone is released to a known screen
#
# Sessions live in a per-channel in-memory hash stamped with created_at.
# Stale sessions (> SESSION_TTL) are swept on every subscribe, and a TV
# unsubscribe destroys its session once no players remain (clause 7).
#
# Usage:
#
#   class SnakePitChannel < ApplicationCable::Channel
#     include ArcadeSession
#     arcade_prefix "snake_pit"     # public stream: "snake_pit:<CODE>"
#
#     def input(data)               # game-specific actions stay here
#       return unless phone? && !@slot.nil?
#       s = session
#       return unless s && s[:phase] == "playing"
#       broadcast_game(type: "input", slot: @slot, dir: data["dir"])
#     end
#
#     private
#
#     def arcade_after_subscribe          # optional hook -- extra streams
#       stream_from "snake_pit:#{@code}:tv" if tv?
#     end
#
#     def arcade_player_disconnected(slot) # optional hook -- mid-match drop
#       broadcast_game(type: "input", slot: slot, dir: "none")
#     end
#   end
#
# Broadcasts on the public stream (every payload includes :type):
#   lobby_update   { players: [{slot, name}], host_slot }
#   player_left    { slot, name, host_slot }   mid-match leave; TV bot-fills
#   game_started   {}
#   game_over      { results }
#   session_reset  { players, host_slot }      abort; everyone back to lobby
#
# Transmissions to the calling socket:
#   state          { phase, players, host_slot }  on subscribe
#   joined         { slot, name, host }
#   join_error     { message }
#   left           {}
module ArcadeSession
  extend ActiveSupport::Concern

  SESSION_TTL = 4.hours
  MAX_SLOTS   = 4

  included do
    const_set(:SESSIONS, {})
    const_set(:SESSIONS_MU, Mutex.new)
  end

  class_methods do
    def arcade_prefix(prefix = nil)
      @arcade_prefix = prefix if prefix
      @arcade_prefix
    end
  end

  def subscribed
    code = params[:code].to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return reject if code.blank? || code.length < 4

    @code = code
    @role = params[:role].to_s
    sweep_sessions
    stream_from stream_name

    sessions_mu.synchronize { sessions[@code] ||= new_session } if tv?

    arcade_after_subscribe

    s = session
    return unless s

    transmit({ type: "state", phase: s[:phase], players: player_list(s),
               host_slot: s[:host_slot] })
  end

  def unsubscribed
    if tv?
      # Clause 7: a TV walking away from an empty lobby takes its session
      # with it. With players still seated we keep the session (the TV can
      # resume via ?code=); the TTL sweep reaps it if nobody comes back.
      sessions_mu.synchronize do
        s = sessions[@code]
        sessions.delete(@code) if s && s[:players].empty?
      end
      return
    end
    return if @slot.nil?

    s = session
    return unless s

    if s[:phase] == "lobby"
      release_slot(s, @slot)
      broadcast_game(type: "lobby_update", players: player_list(s),
                     host_slot: s[:host_slot])
    else
      # Mid-match drop: keep the slot (the phone may reconnect) but mark it
      # disconnected so host promotion skips it, and let the game quiet the
      # runaway avatar.
      sessions_mu.synchronize do
        player = s[:players][@slot]
        player[:connected] = false if player
        promote_host(s) if s[:host_slot] == @slot
      end
      arcade_player_disconnected(@slot)
    end
  end

  # Phone: enter a name, take a slot. The first joiner becomes host.
  def join(data)
    return if tv?

    s = session
    return transmit({ type: "join_error", message: "Game not found" }) unless s
    return transmit({ type: "join_error", message: "Game already started" }) unless s[:phase] == "lobby"

    name = data["name"].to_s.strip.upcase[0, 12]
    return transmit({ type: "join_error", message: "Enter a name" }) if name.blank?

    slot = nil
    sessions_mu.synchronize do
      (0...MAX_SLOTS).each do |i|
        next if s[:players].key?(i)
        s[:players][i] = { name: name, connected: true }
        @slot = i
        slot = i
        break
      end
      s[:host_slot] = slot if !slot.nil? && s[:host_slot].nil?
    end

    return transmit({ type: "join_error", message: "Game is full (#{MAX_SLOTS} players)" }) if slot.nil?

    transmit({ type: "joined", slot: slot, name: name, host: s[:host_slot] == slot })
    broadcast_game(type: "lobby_update", players: player_list(s),
                   host_slot: s[:host_slot])
  end

  # Phone: free my slot. Valid in EVERY phase (clause 4). During a match the
  # TV gets a player_left so it can hand the avatar to a bot.
  def leave(_data = {})
    if phone? && !@slot.nil?
      s = session
      slot = @slot
      @slot = nil
      if s
        player = release_slot(s, slot)
        if s[:phase] == "lobby"
          broadcast_game(type: "lobby_update", players: player_list(s),
                         host_slot: s[:host_slot])
        else
          arcade_player_disconnected(slot)
          broadcast_game(type: "player_left", slot: slot,
                         name: player ? player[:name] : nil,
                         host_slot: s[:host_slot])
        end
      end
    end
    transmit({ type: "left" })
  end

  # TV or the host phone starts the match (clause 3).
  def start_game(_data = {})
    s = session
    return unless s && s[:phase] == "lobby"
    return unless tv? || host?

    sessions_mu.synchronize { s[:phase] = "playing" }
    broadcast_game(type: "game_started")
  end

  # TV: report final results. Phase returns to lobby with slots intact so a
  # rematch keeps the party together (clause 6). Phones that dropped
  # mid-match are cleared out so their seats free up.
  def game_ended(data)
    return unless tv?

    s = session
    return unless s

    reset_to_lobby(s)
    broadcast_game(type: "game_over", results: data["results"] || [])
  end

  # TV: quit or hang up mid-match (clause 5). Same code, same slots, phase
  # back to lobby -- phones land on a known screen and the pit can refill.
  def abort(_data = {})
    return unless tv?

    s = session
    return unless s

    reset_to_lobby(s)
    broadcast_game(type: "session_reset", players: player_list(s),
                   host_slot: s[:host_slot])
  end

  private

  def tv?
    @role == "tv"
  end

  def phone?
    @role == "phone"
  end

  def host?
    s = session
    phone? && !@slot.nil? && s && s[:host_slot] == @slot
  end

  def session
    sessions_mu.synchronize { sessions[@code] }
  end

  def broadcast_game(payload)
    ActionCable.server.broadcast(stream_name, payload)
  end

  def stream_name
    "#{self.class.arcade_prefix}:#{@code}"
  end

  def sessions
    self.class::SESSIONS
  end

  def sessions_mu
    self.class::SESSIONS_MU
  end

  def new_session
    { phase: "lobby", players: {}, host_slot: nil, created_at: Time.current }
  end

  def player_list(s)
    return [] unless s
    s[:players].map { |slot, p| { slot: slot, name: p[:name] } }
  end

  def release_slot(s, slot)
    sessions_mu.synchronize do
      player = s[:players].delete(slot)
      promote_host(s) if s[:host_slot] == slot
      player
    end
  end

  # First occupied slot still holding a live connection wins; failing that,
  # any occupied slot; failing that, nobody (next joiner becomes host).
  def promote_host(s)
    next_slot = s[:players].find { |_, p| p[:connected] != false }&.first
    next_slot = s[:players].keys.first if next_slot.nil?
    s[:host_slot] = next_slot
  end

  def reset_to_lobby(s)
    sessions_mu.synchronize do
      s[:phase] = "lobby"
      s[:players].reject! { |_, p| p[:connected] == false }
      promote_host(s) unless s[:players].key?(s[:host_slot])
    end
  end

  def sweep_sessions
    cutoff = Time.current - SESSION_TTL
    sessions_mu.synchronize do
      sessions.delete_if { |_, s| s[:created_at].nil? || s[:created_at] < cutoff }
    end
  end

  # Hook: called at the end of subscribed (extra streams, e.g. a TV-private
  # pick stream). @code and @role are set; tv?/phone? work.
  def arcade_after_subscribe; end

  # Hook: called when a phone drops or leaves mid-match, with the freed (or
  # frozen) slot. Quiet the avatar here (e.g. broadcast a "none" input).
  def arcade_player_disconnected(_slot); end
end
