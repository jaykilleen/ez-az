class MammothGamesChannel < ApplicationCable::Channel
  # Real-time multiplayer tag game. Each player's own device is the display —
  # there is no shared TV Stage. ArcadeSession handles lobby / slot / host /
  # lifecycle; this channel adds role assignment, position sync, server-side
  # tag / power-up logic, and autonomous bots.
  include ArcadeSession
  arcade_prefix "mammoth_games"

  ARENA_W          = 3000.0
  ARENA_H          = 3000.0
  SPAWN_X          = 1500.0
  SPAWN_Y          = 1500.0
  TAG_RADIUS       = 45.0
  PU_PICKUP_RADIUS = 60.0
  TRAP_RADIUS      = 55.0
  BUFF_DURATION    = 10.0
  PU_COOLDOWN      = 30.0
  TRAP_LIFETIME    = 60.0
  GRACE_PERIOD     = 3.0
  PLAYER_SPD       = 240.0
  BOT_SLOT_BASE    = 1000
  BOT_NAMES        = %w[MAMMOTH BEAST TITAN SHADOW].freeze

  POWER_UP_SPOTS = [
    { id: 0, type: "big_tag",     x: 1350.0, y: 1350.0 },
    { id: 1, type: "speed_boost", x: 1500.0, y: 1290.0 },
    { id: 2, type: "trap",        x: 1650.0, y: 1350.0 },
    { id: 3, type: "big_tag",     x: 1350.0, y: 1650.0 },
    { id: 4, type: "speed_boost", x: 1500.0, y: 1710.0 },
    { id: 5, type: "trap",        x: 1650.0, y: 1650.0 }
  ].freeze

  # No TV host in this game — the first phone subscriber creates the session.
  def arcade_after_subscribe
    sessions_mu.synchronize { sessions[@code] ||= new_session }
  end

  # Host sets the arena before starting (stored in session, broadcast at start).
  def set_arena(data)
    return unless host?
    s = session
    return unless s
    sessions_mu.synchronize { s[:pending_arena] = data["arena"].to_s.presence || "forest" }
  end

  # Host sets the bot count before starting.
  def set_bots(data)
    return unless host?
    s = session
    return unless s
    sessions_mu.synchronize { s[:pending_bots] = data["count"].to_i.clamp(0, 3) }
  end

  # Assign roles, spawn everyone in a ring, add bots, then fire game_started.
  # Bot count and arena are passed directly in the message (more reliable than
  # relying on the separate set_bots/set_arena pre-calls being stored).
  def start_game(data)
    s = session
    return unless s && s[:phase] == "lobby"
    return unless host?

    bot_count = (data["bots"] || s[:pending_bots] || 0).to_i.clamp(0, 3)
    arena     = data["arena"].presence || s[:pending_arena] || "forest"
    now = Time.current.to_f
    sessions_mu.synchronize do
      s[:phase] = "playing"

      bot_count.times do |i|
        s[:players][BOT_SLOT_BASE + i] = {
          name:              BOT_NAMES[i],
          bot:               true,
          connected:         true,
          x:                 SPAWN_X,
          y:                 SPAWN_Y,
          it:                false,
          speed_boost_until: nil,
          big_tag_until:     nil,
          trap_charges:      0,
          heading:           rand * 2 * Math::PI,
          heading_until:     now
        }
      end

      # Spawn everyone in a ring and assign IT randomly
      all_slots = s[:players].keys
      it_slot   = all_slots.sample
      all_slots.each_with_index do |slot, idx|
        angle = (2 * Math::PI * idx) / all_slots.size
        s[:players][slot].merge!(
          it:                slot == it_slot,
          x:                 SPAWN_X + Math.cos(angle) * 200.0,
          y:                 SPAWN_Y + Math.sin(angle) * 200.0,
          speed_boost_until: nil,
          big_tag_until:     nil,
          trap_charges:      0
        )
      end

      s[:power_up_spots] = POWER_UP_SPOTS.map { |pu| pu.merge(cooldown_until: nil) }
      s[:traps]          = []
      s[:started_at]     = now
      s[:last_bot_tick]  = now
    end

    broadcast_game(
      type:           "game_started",
      power_up_spots: power_up_state(s),
      arena:          arena,
      bots:           bot_count
    )
    broadcast_positions(s)
  end

  # Phone: report current position. Server validates, ticks bots, checks tags.
  def move(data)
    return unless phone? && !@slot.nil?
    s = session
    return unless s && s[:phase] == "playing"

    nx = data["x"].to_f.clamp(0.0, ARENA_W)
    ny = data["y"].to_f.clamp(0.0, ARENA_H)
    role_update = nil

    sessions_mu.synchronize do
      p = s[:players][@slot]
      break unless p
      p[:x] = nx
      p[:y] = ny
      role_update = auto_collect(s, @slot, p) if p[:it]
      tick_bots(s)
    end

    check_tags(s)
    check_traps(s)
    broadcast_positions(s)
    transmit(role_payload(s, @slot)) if role_update
  end

  # Phone requests its private role after game_started or after being tagged.
  def request_role(_data = {})
    return unless phone? && !@slot.nil?
    s = session
    return unless s && s[:phase] == "playing"
    transmit(role_payload(s, @slot))
  end

  # Tagger places a trap at their current position (consumes 1 trap charge).
  def place_trap(_data = {})
    return unless phone? && !@slot.nil?
    s = session
    return unless s && s[:phase] == "playing"

    trap = nil
    sessions_mu.synchronize do
      p = s[:players][@slot]
      break unless p && p[:it] && (p[:trap_charges] || 0) > 0
      p[:trap_charges] -= 1
      trap = {
        id:         SecureRandom.hex(4),
        x:          p[:x],
        y:          p[:y],
        expires_at: Time.current.to_f + TRAP_LIFETIME
      }
      s[:traps] << trap
    end

    return unless trap
    broadcast_game(type: "trap_placed", trap: trap)
    transmit(role_payload(s, @slot))
  end

  private

  # Move bots one step. Must be called inside sessions_mu.synchronize.
  def tick_bots(s)
    now = Time.current.to_f
    dt  = [now - (s[:last_bot_tick] || now), 0.1].min
    s[:last_bot_tick] = now
    return if dt < 0.001

    s[:players].each_value do |p|
      next unless p[:bot]

      # Recalculate heading every ~0.8-1.2 s
      if !p[:heading_until] || now >= p[:heading_until]
        if p[:it]
          target = s[:players].values.reject { |q| q[:it] }.min_by { |t| dist2(p, t) }
          p[:heading] = target \
            ? Math.atan2(target[:y] - p[:y], target[:x] - p[:x]) + (rand - 0.5) * 0.5
            : rand * 2 * Math::PI
        else
          chaser = s[:players].values.select { |q| q[:it] }.min_by { |t| dist2(p, t) }
          p[:heading] = chaser \
            ? Math.atan2(p[:y] - chaser[:y], p[:x] - chaser[:x]) + (rand - 0.5) * 0.8
            : rand * 2 * Math::PI
        end
        p[:heading_until] = now + 0.8 + rand * 0.4
      end

      h   = p[:heading] || 0
      spd = PLAYER_SPD
      p[:x] = (p[:x] + Math.cos(h) * spd * dt).clamp(50.0, ARENA_W - 50.0)
      p[:y] = (p[:y] + Math.sin(h) * spd * dt).clamp(50.0, ARENA_H - 50.0)
    end
  end

  def dist2(a, b)
    (a[:x] - b[:x])**2 + (a[:y] - b[:y])**2
  end

  # Auto-collect power-up spots the tagger walks over.
  # Must be called inside sessions_mu.synchronize.
  def auto_collect(s, slot, player)
    now       = Time.current.to_f
    collected = false

    s[:power_up_spots].each do |spot|
      next if spot[:cooldown_until] && spot[:cooldown_until] > now
      dx = player[:x] - spot[:x]
      dy = player[:y] - spot[:y]
      next unless Math.sqrt(dx * dx + dy * dy) < PU_PICKUP_RADIUS

      case spot[:type]
      when "speed_boost" then player[:speed_boost_until] = now + BUFF_DURATION
      when "big_tag"     then player[:big_tag_until]     = now + BUFF_DURATION
      when "trap"        then player[:trap_charges] = (player[:trap_charges] || 0) + 1
      end

      spot[:cooldown_until] = now + PU_COOLDOWN
      collected = true
      broadcast_game(type: "powerup_cooldown", id: spot[:id],
                     cooldown_until: spot[:cooldown_until])
    end

    collected
  end

  def check_tags(s)
    now = Time.current.to_f
    return if s[:started_at] && now - s[:started_at] < GRACE_PERIOD

    newly_tagged = []

    sessions_mu.synchronize do
      s[:players].each do |_it_slot, it_p|
        next unless it_p[:it] && it_p[:connected] != false
        radius = it_p[:big_tag_until] && it_p[:big_tag_until] > now ? TAG_RADIUS * 2 : TAG_RADIUS

        s[:players].each do |runner_slot, runner|
          next if runner[:it] || runner[:connected] == false
          dx = it_p[:x] - runner[:x]
          dy = it_p[:y] - runner[:y]
          if Math.sqrt(dx * dx + dy * dy) < radius
            runner[:it] = true
            newly_tagged << runner_slot
          end
        end
      end
    end

    unless newly_tagged.empty?
      broadcast_game(type: "tagged", slots: newly_tagged)
      check_win(s)
    end
  end

  def check_traps(s)
    now          = Time.current.to_f
    newly_tagged = []

    sessions_mu.synchronize do
      s[:traps].reject! { |t| t[:expires_at] < now }

      s[:players].each do |slot, player|
        next if player[:it] || player[:connected] == false
        s[:traps].each do |trap|
          dx = player[:x] - trap[:x]
          dy = player[:y] - trap[:y]
          if Math.sqrt(dx * dx + dy * dy) < TRAP_RADIUS
            player[:it] = true
            newly_tagged << slot
          end
        end
      end
    end

    unless newly_tagged.empty?
      broadcast_game(type: "tagged", slots: newly_tagged)
      check_win(s)
    end
  end

  def check_win(s)
    runners     = s[:players].count { |_, p| !p[:it] && p[:connected] != false }
    return unless runners <= 1

    winner      = s[:players].find { |_, p| !p[:it] && p[:connected] != false }
    winner_name = winner ? winner[1][:name] : nil
    results     = s[:players].map { |slot, p| { slot: slot, name: p[:name], survived: !p[:it] } }

    broadcast_game(type: "game_over", winner: winner_name, results: results)
    reset_to_lobby(s)
  end

  def broadcast_positions(s)
    positions = s[:players].map do |slot, p|
      { slot: slot, name: p[:name], x: p[:x].round(1), y: p[:y].round(1) }
    end
    broadcast_game(type: "positions", positions: positions)
  end

  def role_payload(s, slot)
    p = s[:players][slot]
    return { type: "your_role", it: false } unless p
    {
      type:              "your_role",
      it:                p[:it],
      speed_boost_until: p[:speed_boost_until],
      big_tag_until:     p[:big_tag_until],
      trap_charges:      p[:trap_charges] || 0
    }
  end

  def power_up_state(s)
    s[:power_up_spots].map { |sp| sp.slice(:id, :type, :x, :y, :cooldown_until) }
  end
end
