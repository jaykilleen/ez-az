require "concurrent-ruby"

# Real-time arena game. Server runs the authoritative simulation in a
# Concurrent::TimerTask at TICK_HZ; phones send press/release input events;
# the TV is a pure render-from-state client that interpolates between snapshots.
class BoomerangChannel < ApplicationCable::Channel
  SESSIONS    = {}
  SESSIONS_MU = Mutex.new
  TICKERS     = {}    # one TimerTask per room
  TICKERS_MU  = Mutex.new

  SLOT_COLORS = {
    1 => "#ff4757",
    2 => "#3742fa",
    3 => "#ffa502",
    4 => "#2ed573"
  }.freeze

  TICK_HZ            = 20
  TICK_INTERVAL      = 1.0 / TICK_HZ        # 50ms

  ARENA_W            = 800
  ARENA_H            = 500
  WALL_PAD           = 30                   # spawn inset from arena edge

  PLAYER_R           = 18
  PLAYER_SPEED       = 140                  # px/sec
  PLAYER_HIT_R       = 24                   # boomerang hit radius (player+rang combined-ish)

  BOOM_R             = 10
  BOOM_SPEED         = 360
  BOOM_OUT_DIST      = 240                  # how far before it turns around
  BOOM_CATCH_R       = 28                   # radius for owner to catch returning rang
  BOOM_THROW_OFFSET  = 22                   # spawn ahead of player so it doesn't insta-hit owner

  ROUND_MAX_SECONDS  = 35
  ROUND_OVER_PAUSE   = 2.5
  ROUNDS_TO_WIN      = 2
  MIN_PLAYERS        = 2

  ALLOWED_DIRS = %w[up down left right].freeze

  # ── Connection lifecycle ─────────────────────────────────────────────

  def subscribed
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return reject unless @room

    stream_from stream_key

    s = get_session
    return unless s

    # Catch up a late TV (reload) or phone (reconnect) with the latest state.
    transmit(snapshot_payload(s)) if s[:phase] == "playing" || s[:phase] == "round_over"
    transmit(match_over_payload(s)) if s[:phase] == "match_over"
    transmit(lobby_payload(s)) if s[:phase] == "lobby"
  end

  def unsubscribed
    # Tickers are stopped on match end; nothing to do per-subscriber.
  end

  # ── TV controls ───────────────────────────────────────────────────────

  def start_match(_data)
    return unless tv?
    players = @room.memberships.where(role: :player).order(:slot).pluck(:slot)
    return transmit({ type: "error", message: "Need #{MIN_PLAYERS}+ players" }) if players.length < MIN_PLAYERS

    s = build_session(players)
    @room.update!(state: :playing)
    RoomChannel.game_starting(@room)
    start_ticker(@room.code)
    ActionCable.server.broadcast(stream_key, snapshot_payload(s))
  end

  def reset(_data)
    return unless tv?
    stop_ticker(@room.code)
    SESSIONS_MU.synchronize { SESSIONS.delete(@room.code) }
    @room.update!(state: :lobby) if @room.state == "playing"
    ActionCable.server.broadcast(stream_key, { type: "reset" })
  end

  # ── Phone input ───────────────────────────────────────────────────────

  # data: { dir: "up"|"down"|"left"|"right", state: "press"|"release" }
  def input(data)
    return if tv?
    s = get_session
    return unless s

    slot = params[:slot].to_i
    p = s[:players][slot]
    return unless p

    dir = data["dir"].to_s
    return unless ALLOWED_DIRS.include?(dir)
    pressed = data["state"].to_s != "release"

    SESSIONS_MU.synchronize do
      p[:held][dir.to_sym] = pressed
    end
  end

  # data: {}
  def throw(_data)
    return if tv?
    s = get_session
    return unless s && s[:phase] == "playing"

    slot = params[:slot].to_i
    p = s[:players][slot]
    return unless p && p[:alive]
    return if s[:boomerangs].any? { |b| b[:owner] == slot }

    fx, fy = p[:facing]
    SESSIONS_MU.synchronize do
      s[:boomerangs] << {
        id:       SecureRandom.hex(4),
        owner:    slot,
        x:        p[:x] + fx * BOOM_THROW_OFFSET,
        y:        p[:y] + fy * BOOM_THROW_OFFSET,
        dx:       fx * BOOM_SPEED,
        dy:       fy * BOOM_SPEED,
        traveled: 0.0,
        phase:    "out"
      }
    end
  end

  private

  def tv?
    params[:role] == "tv"
  end

  def stream_key
    "boomerang:#{@room.code}"
  end

  def get_session
    SESSIONS_MU.synchronize { SESSIONS[@room.code] }
  end

  def save_session(s)
    SESSIONS_MU.synchronize { SESSIONS[@room.code] = s }
  end

  # ── Session building ─────────────────────────────────────────────────

  def build_session(player_slots)
    spawns = corner_spawns(player_slots.length)
    players = {}
    player_slots.each_with_index do |slot, i|
      sx, sy, fx, fy = spawns[i]
      players[slot] = build_player(slot, sx, sy, fx, fy)
    end

    s = {
      phase:           "playing",
      round:           1,
      rounds_to_win:   ROUNDS_TO_WIN,
      scores:          player_slots.to_h { |sl| [sl, 0] },
      players:         players,
      boomerangs:      [],
      player_slots:    player_slots,
      round_started_at: Time.current.to_f,
      round_winner:    nil,
      match_winner:    nil
    }
    save_session(s)
    s
  end

  def reset_round(s)
    spawns = corner_spawns(s[:player_slots].length)
    s[:player_slots].each_with_index do |slot, i|
      sx, sy, fx, fy = spawns[i]
      s[:players][slot] = build_player(slot, sx, sy, fx, fy, name_override: s[:players][slot][:name])
    end
    s[:boomerangs] = []
    s[:phase] = "playing"
    s[:round_started_at] = Time.current.to_f
    s[:round_winner] = nil
  end

  def build_player(slot, sx, sy, fx, fy, name_override: nil)
    {
      slot:   slot,
      x:      sx,
      y:      sy,
      vx:     0.0,
      vy:     0.0,
      facing: [fx, fy],
      alive:  true,
      held:   { up: false, down: false, left: false, right: false },
      color:  SLOT_COLORS[slot],
      name:   name_override || (@room.memberships.find_by(slot: slot)&.name || "P#{slot}")
    }
  end

  def corner_spawns(count)
    # [x, y, facing_x, facing_y] — face toward arena centre.
    cx = ARENA_W / 2.0
    cy = ARENA_H / 2.0
    corners = [
      [WALL_PAD,             WALL_PAD],
      [ARENA_W - WALL_PAD,   ARENA_H - WALL_PAD],
      [ARENA_W - WALL_PAD,   WALL_PAD],
      [WALL_PAD,             ARENA_H - WALL_PAD]
    ].first(count)
    corners.map do |x, y|
      dx = cx - x
      dy = cy - y
      mag = Math.sqrt(dx * dx + dy * dy)
      [x, y, dx / mag, dy / mag]
    end
  end

  # ── Ticker ────────────────────────────────────────────────────────────

  def start_ticker(room_code)
    stop_ticker(room_code)
    task = Concurrent::TimerTask.new(execution_interval: TICK_INTERVAL, run_now: false) do
      tick_room(room_code)
    end
    task.execute
    TICKERS_MU.synchronize { TICKERS[room_code] = task }
  end

  def stop_ticker(room_code)
    task = TICKERS_MU.synchronize { TICKERS.delete(room_code) }
    task&.shutdown
  end

  # Stand-alone class method so it can be called from the timer thread without
  # depending on per-channel-instance state.
  def tick_room(room_code)
    s = SESSIONS_MU.synchronize { SESSIONS[room_code] }
    return unless s

    case s[:phase]
    when "playing"
      tick_playing(s, room_code)
    when "round_over"
      tick_round_over(s, room_code)
    end
  rescue => e
    Rails.logger.error("[BoomerangChannel] tick error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}")
  end

  def tick_playing(s, room_code)
    dt = TICK_INTERVAL

    SESSIONS_MU.synchronize do
      # 1. Apply held inputs to velocities, integrate positions, update facing.
      s[:players].each_value do |p|
        next unless p[:alive]
        ax = (p[:held][:right] ? 1 : 0) - (p[:held][:left] ? 1 : 0)
        ay = (p[:held][:down]  ? 1 : 0) - (p[:held][:up]   ? 1 : 0)
        if ax != 0 || ay != 0
          mag = Math.sqrt(ax * ax + ay * ay)
          ndx = ax / mag
          ndy = ay / mag
          p[:vx] = ndx * PLAYER_SPEED
          p[:vy] = ndy * PLAYER_SPEED
          p[:facing] = [ndx, ndy]
        else
          p[:vx] = 0.0
          p[:vy] = 0.0
        end
        p[:x] = (p[:x] + p[:vx] * dt).clamp(PLAYER_R, ARENA_W - PLAYER_R)
        p[:y] = (p[:y] + p[:vy] * dt).clamp(PLAYER_R, ARENA_H - PLAYER_R)
      end

      # 2. Advance boomerangs.
      s[:boomerangs].each do |b|
        if b[:phase] == "out"
          b[:x] += b[:dx] * dt
          b[:y] += b[:dy] * dt
          b[:traveled] += BOOM_SPEED * dt
          # Bounce off arena walls (one bounce, then keep flying)
          if b[:x] <= BOOM_R || b[:x] >= ARENA_W - BOOM_R
            b[:dx] = -b[:dx]
            b[:x]  = b[:x].clamp(BOOM_R, ARENA_W - BOOM_R)
          end
          if b[:y] <= BOOM_R || b[:y] >= ARENA_H - BOOM_R
            b[:dy] = -b[:dy]
            b[:y]  = b[:y].clamp(BOOM_R, ARENA_H - BOOM_R)
          end
          # Switch to homing return after travel distance
          if b[:traveled] >= BOOM_OUT_DIST
            b[:phase] = "returning"
          end
        else
          # Returning: home toward owner each tick
          owner = s[:players][b[:owner]]
          if owner && owner[:alive]
            tx = owner[:x] - b[:x]
            ty = owner[:y] - b[:y]
            mag = Math.sqrt(tx * tx + ty * ty)
            if mag > 0.0001
              b[:dx] = tx / mag * BOOM_SPEED
              b[:dy] = ty / mag * BOOM_SPEED
            end
          end
          b[:x] += b[:dx] * dt
          b[:y] += b[:dy] * dt
        end
      end

      # 3. Collisions: boomerang vs player.
      s[:boomerangs].each do |b|
        s[:players].each_value do |p|
          next unless p[:alive]
          # Owner can catch returning rang
          if b[:phase] == "returning" && p[:slot] == b[:owner]
            if dist(b[:x], b[:y], p[:x], p[:y]) < BOOM_CATCH_R
              b[:caught] = true
              break
            end
            next
          end
          # Owner can't be hit by their own outbound rang
          next if p[:slot] == b[:owner] && b[:phase] == "out"
          if dist(b[:x], b[:y], p[:x], p[:y]) < PLAYER_HIT_R
            p[:alive] = false
            b[:caught] = true # consume the rang so it stops
            broadcast_event(room_code, { type: "hit", victim: p[:slot], by: b[:owner] })
            break
          end
        end
      end

      # 4. Despawn caught/returned-and-touched boomerangs.
      s[:boomerangs].reject! { |b| b[:caught] }

      # 5. Round end check.
      alive = s[:players].values.select { |p| p[:alive] }
      elapsed = Time.current.to_f - s[:round_started_at]
      round_ended = false
      winner_slot = nil

      if alive.length <= 1
        round_ended = true
        winner_slot = alive.first&.dig(:slot)
      elsif elapsed >= ROUND_MAX_SECONDS
        round_ended = true
        winner_slot = nil
      end

      if round_ended
        s[:phase] = "round_over"
        s[:round_winner] = winner_slot
        s[:round_ended_at] = Time.current.to_f
        s[:scores][winner_slot] += 1 if winner_slot
        # Match end?
        max_score = s[:scores].values.max
        if max_score >= ROUNDS_TO_WIN
          match_winner = s[:scores].max_by { |_, v| v }.first
          s[:phase] = "match_over"
          s[:match_winner] = match_winner
          stop_ticker(room_code)
          record_score(s)
          ActionCable.server.broadcast(stream_for_code(room_code), match_over_payload(s))
          return
        else
          ActionCable.server.broadcast(stream_for_code(room_code), round_over_payload(s))
        end
      end
    end

    # Always send a tick snapshot for smooth render.
    ActionCable.server.broadcast(stream_for_code(room_code), snapshot_payload(s))
  end

  def tick_round_over(s, room_code)
    elapsed = Time.current.to_f - (s[:round_ended_at] || Time.current.to_f)
    return unless elapsed >= ROUND_OVER_PAUSE
    SESSIONS_MU.synchronize do
      s[:round] += 1
      reset_round(s)
    end
    ActionCable.server.broadcast(stream_for_code(room_code), snapshot_payload(s))
  end

  def stream_for_code(code)
    "boomerang:#{code}"
  end

  def broadcast_event(room_code, payload)
    ActionCable.server.broadcast(stream_for_code(room_code), payload)
  end

  def dist(ax, ay, bx, by)
    dx = ax - bx
    dy = ay - by
    Math.sqrt(dx * dx + dy * dy)
  end

  # ── Payloads ──────────────────────────────────────────────────────────

  def snapshot_payload(s)
    {
      type:       "tick",
      t:          (Time.current.to_f * 1000).to_i,
      phase:      s[:phase],
      round:      s[:round],
      rounds_to_win: s[:rounds_to_win],
      arena:      { w: ARENA_W, h: ARENA_H },
      scores:     s[:scores],
      round_winner: s[:round_winner],
      players:    s[:players].values.map do |p|
        {
          slot:   p[:slot],
          name:   p[:name],
          color:  p[:color],
          x:      p[:x].round(1),
          y:      p[:y].round(1),
          fx:     p[:facing][0].round(2),
          fy:     p[:facing][1].round(2),
          alive:  p[:alive]
        }
      end,
      boomerangs: s[:boomerangs].map do |b|
        {
          id:    b[:id],
          owner: b[:owner],
          color: SLOT_COLORS[b[:owner]],
          x:     b[:x].round(1),
          y:     b[:y].round(1),
          phase: b[:phase]
        }
      end
    }
  end

  def lobby_payload(s)
    { type: "lobby", scores: s ? s[:scores] : {} }
  end

  def round_over_payload(s)
    snap = snapshot_payload(s)
    snap.merge(type: "round_over", round_winner: s[:round_winner])
  end

  def match_over_payload(s)
    {
      type:         "match_over",
      match_winner: s[:match_winner],
      winner_name:  s[:players].dig(s[:match_winner], :name),
      winner_color: SLOT_COLORS[s[:match_winner]],
      scores:       s[:scores],
      players:      s[:players].values.map { |p| { slot: p[:slot], name: p[:name], color: p[:color] } }
    }
  end

  def record_score(s)
    return unless s[:match_winner]
    name = s[:players].dig(s[:match_winner], :name) || "?"
    Score.create(game: "boomerang-brawl", value: s[:scores][s[:match_winner]] * 100, name: name)
  rescue ActiveRecord::RecordInvalid
    nil
  end
end
