require "test_helper"

# Tests for SnakePitChannel and, through it, the shared ArcadeSession
# concern -- the server half of the Phone Contract (build-game Phase 4C):
#
#   clause 3: host election + host start (with fallback when the host drops)
#   clause 4: leave frees the slot in EVERY phase
#   clause 5: abort resets the session to lobby; the code stays joinable
#   clause 6: game_ended keeps slots so a rematch keeps the party
#   clause 7: created_at TTL sweep + TV unsubscribe cleanup
class SnakePitChannelTest < ActionCable::Channel::TestCase
  tests SnakePitChannel

  CODE   = "PITT"
  STREAM = "snake_pit:#{CODE}"

  setup do
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS.clear }
  end

  def seed_session(code: CODE, phase: "lobby", players: {}, host_slot: nil, created_at: Time.current)
    SnakePitChannel::SESSIONS_MU.synchronize do
      SnakePitChannel::SESSIONS[code] = {
        phase: phase, players: players, host_slot: host_slot, created_at: created_at
      }
    end
  end

  def session(code = CODE)
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[code] }
  end

  def stream_messages
    broadcasts(STREAM).map { |m| JSON.parse(m) }
  end

  # ── Subscribe ────────────────────────────────────────────────────────────

  test "tv subscribe creates a session with a created_at stamp" do
    subscribe code: CODE, role: "tv"

    assert subscription.confirmed?
    assert_has_stream STREAM
    s = session
    assert_equal "lobby", s[:phase]
    assert_not_nil s[:created_at]
  end

  test "rejects a short or blank code" do
    subscribe code: "AB", role: "phone"
    assert subscription.rejected?
  end

  test "subscriber receives current state including host_slot" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "phone"

    state = transmissions.find { |t| t["type"] == "state" }
    assert_not_nil state
    assert_equal "lobby", state["phase"]
    assert_equal 0, state["host_slot"]
    assert_equal [{ "slot" => 0, "name" => "ALICE" }], state["players"]
  end

  # ── Host election (clause 3) ─────────────────────────────────────────────

  test "first joiner becomes host" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"

    joined = transmissions.find { |t| t["type"] == "joined" }
    assert_equal 0, joined["slot"]
    assert joined["host"], "first joiner should be host"
    assert_equal 0, session[:host_slot]
  end

  test "later joiners are not host" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "phone"
    perform :join, name: "BOB"

    joined = transmissions.find { |t| t["type"] == "joined" }
    assert_equal 1, joined["slot"]
    assert_not joined["host"]
    assert_equal 0, session[:host_slot]
  end

  test "host start_game begins the match" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    perform :start_game

    assert_equal "playing", session[:phase]
    assert stream_messages.any? { |m| m["type"] == "game_started" }
  end

  test "non-host phone cannot start the match" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "phone"
    perform :join, name: "BOB"
    perform :start_game

    assert_equal "lobby", session[:phase]
    assert_not stream_messages.any? { |m| m["type"] == "game_started" }
  end

  test "tv can start the match" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "tv"
    perform :start_game

    assert_equal "playing", session[:phase]
    assert stream_messages.any? { |m| m["type"] == "game_started" }
  end

  test "host leaving promotes the next occupied slot" do
    seed_session(players: { 1 => { name: "BOB", connected: true } })

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE" # takes slot 0, becomes host (host_slot was nil)
    assert_equal 0, session[:host_slot]

    perform :leave

    assert_equal 1, session[:host_slot], "BOB should inherit the host seat"
  end

  test "host unsubscribe mid-match promotes a connected player" do
    seed_session(players: { 1 => { name: "BOB", connected: true } })

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[CODE][:phase] = "playing" }

    unsubscribe

    s = session
    assert_equal 1, s[:host_slot], "host should pass to BOB when ALICE drops"
    assert_equal false, s[:players][0][:connected], "ALICE keeps her slot but is marked disconnected"
  end

  # ── Leave in every phase (clause 4) ──────────────────────────────────────

  test "leave frees the slot in the lobby" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    perform :leave

    assert_empty session[:players]
    assert transmissions.any? { |t| t["type"] == "left" }
    update = stream_messages.reverse.find { |m| m["type"] == "lobby_update" }
    assert_equal [], update["players"]
  end

  test "leave frees the slot mid-match and tells the TV to bot-fill" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[CODE][:phase] = "playing" }

    perform :leave

    assert_empty session[:players]
    msgs = stream_messages
    left = msgs.find { |m| m["type"] == "player_left" }
    assert_not_nil left, "TV needs player_left to hand the snake to a bot"
    assert_equal 0, left["slot"]
    assert_equal "ALICE", left["name"]
    assert msgs.any? { |m| m["type"] == "input" && m["dir"] == "none" },
           "the snake should stop turning when its phone leaves"
    assert transmissions.any? { |t| t["type"] == "left" }
  end

  test "leave after game over (lobby phase again) frees the slot" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[CODE][:phase] = "playing" }
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[CODE][:phase] = "lobby" }

    perform :leave

    assert_empty session[:players]
    assert transmissions.any? { |t| t["type"] == "left" }
  end

  # ── Abort resets the session (clause 5) ──────────────────────────────────

  test "abort resets a playing session to lobby and broadcasts session_reset" do
    seed_session(phase: "playing",
                 players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "tv"
    perform :abort

    assert_equal "lobby", session[:phase]
    reset = stream_messages.find { |m| m["type"] == "session_reset" }
    assert_not_nil reset
    assert_equal 0, reset["host_slot"]
    assert_equal [{ "slot" => 0, "name" => "ALICE" }], reset["players"]
  end

  test "abort drops disconnected players and re-elects the host" do
    seed_session(phase: "playing", host_slot: 0, players: {
      0 => { name: "GHOST", connected: false },
      1 => { name: "BOB",   connected: true }
    })

    subscribe code: CODE, role: "tv"
    perform :abort

    s = session
    assert_equal [1], s[:players].keys
    assert_equal 1, s[:host_slot]
  end

  test "a new phone can join the same code after an abort" do
    seed_session(phase: "playing",
                 players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "tv"
    perform :abort
    unsubscribe

    subscribe code: CODE, role: "phone"
    perform :join, name: "BOB"

    joined = transmissions.find { |t| t["type"] == "joined" }
    assert_not_nil joined, "the code must stay joinable after a TV quit"
    assert_equal 1, joined["slot"]
  end

  test "phones cannot abort" do
    seed_session(phase: "playing",
                 players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "phone"
    perform :abort

    assert_equal "playing", session[:phase]
  end

  # ── Rematch keeps the party (clause 6) ───────────────────────────────────

  test "game_ended returns to lobby keeping connected players' slots" do
    seed_session(phase: "playing", host_slot: 1, players: {
      0 => { name: "ALICE", connected: true },
      1 => { name: "GHOST", connected: false }
    })

    subscribe code: CODE, role: "tv"
    perform :game_ended, results: [{ "slot" => 0, "score" => 120, "rank" => 1 }]

    s = session
    assert_equal "lobby", s[:phase]
    assert_equal [0], s[:players].keys, "connected players keep slots; ghosts are cleared"
    assert_equal 0, s[:host_slot], "host re-elected away from the dropped phone"
    over = stream_messages.find { |m| m["type"] == "game_over" }
    assert_equal 120, over["results"].first["score"]
  end

  # ── Sessions die (clause 7) ──────────────────────────────────────────────

  test "stale sessions are swept on subscribe" do
    seed_session(code: "OLDC", created_at: 5.hours.ago)

    subscribe code: CODE, role: "tv"

    assert_nil session("OLDC"), "a session past the TTL should be swept"
    assert_not_nil session(CODE)
  end

  test "fresh sessions survive the sweep" do
    seed_session(code: "FRSH", created_at: 1.hour.ago)

    subscribe code: CODE, role: "tv"

    assert_not_nil session("FRSH")
  end

  test "tv unsubscribe destroys an empty session" do
    subscribe code: CODE, role: "tv"
    assert_not_nil session

    unsubscribe

    assert_nil session
  end

  test "tv unsubscribe keeps a session that still has players" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "tv"
    unsubscribe

    assert_not_nil session, "players are still seated; the TTL sweep owns cleanup"
  end

  # ── Game input (snake-specific, unchanged behaviour) ─────────────────────

  test "input relays direction on the public stream while playing" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    SnakePitChannel::SESSIONS_MU.synchronize { SnakePitChannel::SESSIONS[CODE][:phase] = "playing" }

    perform :input, dir: "up"

    input = stream_messages.find { |m| m["type"] == "input" && m["dir"] == "up" }
    assert_not_nil input
    assert_equal 0, input["slot"]
  end

  test "input is ignored in the lobby" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    perform :input, dir: "up"

    assert_not stream_messages.any? { |m| m["type"] == "input" }
  end

  test "join is rejected once the match has started" do
    seed_session(phase: "playing")

    subscribe code: CODE, role: "phone"
    perform :join, name: "LATE"

    err = transmissions.find { |t| t["type"] == "join_error" }
    assert_match(/already started/i, err["message"])
  end

  test "join is rejected when the pit is full" do
    seed_session(players: {
      0 => { name: "A", connected: true }, 1 => { name: "B", connected: true },
      2 => { name: "C", connected: true }, 3 => { name: "D", connected: true }
    }, host_slot: 0)

    subscribe code: CODE, role: "phone"
    perform :join, name: "FIFTH"

    err = transmissions.find { |t| t["type"] == "join_error" }
    assert_match(/full/i, err["message"])
  end
end
