require "test_helper"

# Tests for GoldenGoalChannel and, through it, the shared ArcadeSession
# concern -- the server half of the Phone Contract (build-game Phase 4C):
#
#   clause 3: host election + host start (with fallback when the host drops)
#   clause 4: leave frees the slot in EVERY phase
#   clause 5: abort resets the session to lobby; the code stays joinable
#   clause 6: game_ended keeps slots so a rematch keeps the party
#   clause 7: created_at TTL sweep + TV unsubscribe cleanup
#
# Plus Golden Goal's twist: secret picks relay ONLY on the TV-private
# stream, and the TV's public relay (tv_event) is whitelisted.
class GoldenGoalChannelTest < ActionCable::Channel::TestCase
  tests GoldenGoalChannel

  CODE      = "GOAL"
  STREAM    = "golden_goal:#{CODE}"
  TV_STREAM = "golden_goal:#{CODE}:tv"

  setup do
    GoldenGoalChannel::SESSIONS_MU.synchronize { GoldenGoalChannel::SESSIONS.clear }
  end

  def seed_session(code: CODE, phase: "lobby", players: {}, host_slot: nil, created_at: Time.current)
    GoldenGoalChannel::SESSIONS_MU.synchronize do
      GoldenGoalChannel::SESSIONS[code] = {
        phase: phase, players: players, host_slot: host_slot, created_at: created_at
      }
    end
  end

  def session(code = CODE)
    GoldenGoalChannel::SESSIONS_MU.synchronize { GoldenGoalChannel::SESSIONS[code] }
  end

  def stream_messages(stream = STREAM)
    broadcasts(stream).map { |m| JSON.parse(m) }
  end

  def set_phase(phase)
    GoldenGoalChannel::SESSIONS_MU.synchronize { GoldenGoalChannel::SESSIONS[CODE][:phase] = phase }
  end

  # ── Subscribe ────────────────────────────────────────────────────────────

  test "tv subscribe creates a session, the public stream and the private pick stream" do
    subscribe code: CODE, role: "tv"

    assert subscription.confirmed?
    assert_has_stream STREAM
    assert_has_stream TV_STREAM
    s = session
    assert_equal "lobby", s[:phase]
    assert_not_nil s[:created_at]
  end

  test "phone subscribe does NOT get the TV-private pick stream" do
    seed_session

    subscribe code: CODE, role: "phone"

    assert subscription.confirmed?
    assert_has_stream STREAM
    assert_has_no_stream TV_STREAM
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
    set_phase "playing"

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
    set_phase "playing"

    perform :leave

    assert_empty session[:players]
    left = stream_messages.find { |m| m["type"] == "player_left" }
    assert_not_nil left, "TV needs player_left to hand the striker to a bot"
    assert_equal 0, left["slot"]
    assert_equal "ALICE", left["name"]
    assert transmissions.any? { |t| t["type"] == "left" }
  end

  test "leave after game over (lobby phase again) frees the slot" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    set_phase "playing"
    set_phase "lobby"

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
    perform :game_ended, results: [{ "slot" => 0, "score" => 4, "rank" => 1 }]

    s = session
    assert_equal "lobby", s[:phase]
    assert_equal [0], s[:players].keys, "connected players keep slots; ghosts are cleared"
    assert_equal 0, s[:host_slot], "host re-elected away from the dropped phone"
    over = stream_messages.find { |m| m["type"] == "game_over" }
    assert_equal 4, over["results"].first["score"]
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

  # ── Secret picks (Golden Goal specific) ──────────────────────────────────

  test "pick relays on the TV-private stream and never the public one" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    set_phase "playing"

    perform :pick, kind: "shot", aim: "left", height: "high"

    tv_pick = stream_messages(TV_STREAM).find { |m| m["type"] == "pick" }
    assert_not_nil tv_pick, "the pick must reach the TV"
    assert_equal 0, tv_pick["slot"]
    assert_equal "shot", tv_pick["kind"]
    assert_equal "left", tv_pick["aim"]
    assert_equal "high", tv_pick["height"]
    assert_not stream_messages.any? { |m| m["type"] == "pick" },
               "a secret pick must NEVER appear on the public stream"
  end

  test "pick is ignored in the lobby" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"

    perform :pick, kind: "shot", aim: "left", height: "high"

    assert_empty stream_messages(TV_STREAM)
  end

  test "pick rejects values outside the whitelist" do
    seed_session

    subscribe code: CODE, role: "phone"
    perform :join, name: "ALICE"
    set_phase "playing"

    perform :pick, kind: "shot", aim: "top-bins", height: "high"

    assert_empty stream_messages(TV_STREAM)
  end

  # ── TV event relay whitelist (Golden Goal specific) ──────────────────────

  test "tv_event relays a whitelisted event on the public stream" do
    seed_session

    subscribe code: CODE, role: "tv"
    perform :tv_event, event: "round_setup", payload: { "round" => 1, "striker" => 0, "keeper" => 1 }

    setup_msg = stream_messages.find { |m| m["type"] == "round_setup" }
    assert_not_nil setup_msg
    assert_equal 1, setup_msg["round"]
    assert_equal 0, setup_msg["striker"]
  end

  test "tv_event drops events not on the whitelist" do
    seed_session

    subscribe code: CODE, role: "tv"
    perform :tv_event, event: "pick", payload: { "slot" => 0, "aim" => "left" }

    assert_not stream_messages.any? { |m| m["type"] == "pick" },
               "the whitelist must stop the TV leaking pick-shaped events"
  end

  test "phones cannot tv_event" do
    seed_session(players: { 0 => { name: "ALICE", connected: true } }, host_slot: 0)

    subscribe code: CODE, role: "phone"
    perform :tv_event, event: "scoreboard", payload: { "scores" => [] }

    assert_not stream_messages.any? { |m| m["type"] == "scoreboard" }
  end

  test "join is rejected once the match has started" do
    seed_session(phase: "playing")

    subscribe code: CODE, role: "phone"
    perform :join, name: "LATE"

    err = transmissions.find { |t| t["type"] == "join_error" }
    assert_match(/already started/i, err["message"])
  end

  test "join is rejected when the shootout is full" do
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
