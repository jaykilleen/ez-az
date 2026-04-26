require "test_helper"

# Tests for TriviaChannel — the game engine for Family Trivia.
#
# Game flow:
#   TV subscribes (role: tv) → start_game → reading phase →
#   start_answering → phones answer → all-in triggers reveal →
#   next_question (or game_over)
#
# The channel uses SESSIONS (in-memory hash) for game state.
# Each test must clear it to avoid leakage.
class TriviaChannelTest < ActionCable::Channel::TestCase
  tests TriviaChannel

  setup do
    Room.delete_all
    Player.delete_all
    @room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    @p1 = @room.memberships.create!(name: "ALICE", slot: 1, role: :player, session_id: SecureRandom.hex(8))
    @p2 = @room.memberships.create!(name: "BOB",   slot: 2, role: :player, session_id: SecureRandom.hex(8))
    TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS.clear }
  end

  # ── Subscribe ─────────────────────────────────────────────────────────────

  test "TV subscribes and streams from trivia stream" do
    subscribe code: @room.code, role: "tv"
    assert subscription.confirmed?
    assert_has_stream "trivia:#{@room.code}"
  end

  test "phone subscribes with slot and streams from trivia stream" do
    subscribe code: @room.code, slot: 1
    assert subscription.confirmed?
    assert_has_stream "trivia:#{@room.code}"
  end

  test "rejects unknown room code" do
    subscribe code: "XXXX", role: "tv"
    assert subscription.rejected?
  end

  test "rejects expired room" do
    @room.update_column(:expires_at, 1.minute.ago)
    subscribe code: @room.code, role: "tv"
    assert subscription.rejected?
  end

  test "late TV subscriber receives current question during reading phase" do
    # Pre-seed session in reading phase
    session = { phase: "reading", q_index: 0, order: [0], scores: {}, answers: {} }
    TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] = session }

    subscribe code: @room.code, role: "tv"

    q_event = transmissions.find { |t| t["type"] == "question" }
    assert_not_nil q_event
    assert_equal 0, q_event["q_index"]
  end

  test "late phone subscriber receives question and answering events during answering phase" do
    q = TriviaChannel::QUESTIONS.first
    session = { phase: "answering", q_index: 0, order: [0], scores: {}, answers: {} }
    TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] = session }

    subscribe code: @room.code, slot: 1

    types = transmissions.map { |t| t["type"] }
    assert_includes types, "question"
    assert_includes types, "answering"
  end

  # ── start_game ────────────────────────────────────────────────────────────

  test "start_game broadcasts the first question" do
    subscribe code: @room.code, role: "tv"

    perform :start_game

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    q_event = msgs.find { |m| m["type"] == "question" }
    assert_not_nil q_event
    assert_equal 0, q_event["q_index"]
    assert_not_nil q_event["question"]
    assert_not_nil q_event["category"]
  end

  test "start_game marks room as playing" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    assert @room.reload.playing?
  end

  test "start_game builds a session with shuffled question order" do
    subscribe code: @room.code, role: "tv"
    perform :start_game

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    assert_not_nil session
    assert_equal "reading", session[:phase]
    assert_equal 0, session[:q_index]
    assert session[:order].is_a?(Array)
    assert session[:order].length > 0
  end

  test "start_game is ignored by phone subscribers" do
    subscribe code: @room.code, slot: 1
    before = broadcasts("trivia:#{@room.code}").size

    perform :start_game

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  # ── start_answering ────────────────────────────────────────────────────────

  test "start_answering transitions phase and broadcasts options" do
    subscribe code: @room.code, role: "tv"
    perform :start_game

    perform :start_answering

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    answering = msgs.find { |m| m["type"] == "answering" }
    assert_not_nil answering
    assert_equal 4, answering["options"].length
  end

  test "start_answering is ignored outside reading phase" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    # Now in answering phase — calling again should be ignored
    before = broadcasts("trivia:#{@room.code}").size

    perform :start_answering

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  # ── answer ────────────────────────────────────────────────────────────────

  test "phone answer broadcasts player_answered" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    unsubscribe

    # Re-subscribe as phone player
    subscribe code: @room.code, slot: 1
    perform :answer, "index" => 0

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    answered = msgs.find { |m| m["type"] == "player_answered" }
    assert_not_nil answered
    assert_equal 1, answered["slot"]
    assert_equal 1, answered["answered_count"]
  end

  test "answer is ignored during reading phase" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    unsubscribe

    subscribe code: @room.code, slot: 1
    before = broadcasts("trivia:#{@room.code}").size

    perform :answer, "index" => 0

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  test "answer ignored if player already answered" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    unsubscribe

    subscribe code: @room.code, slot: 1
    perform :answer, "index" => 0
    before = broadcasts("trivia:#{@room.code}").size

    perform :answer, "index" => 1  # second attempt

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  test "all players answering triggers automatic reveal" do
    # Set up: 1 player only so one answer triggers reveal
    @p2.destroy
    @room.memberships.reload

    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    unsubscribe

    subscribe code: @room.code, slot: 1
    perform :answer, "index" => 0

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    assert msgs.any? { |m| m["type"] == "revealed" }, "expected revealed after all players answered"
  end

  test "correct answer increments score" do
    @p2.destroy

    subscribe code: @room.code, role: "tv"
    perform :start_game

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    q = TriviaChannel::QUESTIONS[session[:order][0]]
    correct_index = q[:answer]
    perform :start_answering
    unsubscribe

    subscribe code: @room.code, slot: 1
    perform :answer, "index" => correct_index

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    assert_equal 1, session[:scores]["1"], "correct answer should score 1 point"
  end

  test "wrong answer does not increment score" do
    @p2.destroy

    subscribe code: @room.code, role: "tv"
    perform :start_game

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    q = TriviaChannel::QUESTIONS[session[:order][0]]
    wrong_index = (q[:answer] + 1) % 4
    perform :start_answering
    unsubscribe

    subscribe code: @room.code, slot: 1
    perform :answer, "index" => wrong_index

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    assert_nil session[:scores]["1"], "wrong answer should not score"
  end

  # ── reveal ────────────────────────────────────────────────────────────────

  test "TV reveal broadcasts correct answer and results" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering

    perform :reveal

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    revealed = msgs.find { |m| m["type"] == "revealed" }
    assert_not_nil revealed
    assert_not_nil revealed["correct_index"]
    assert_not_nil revealed["correct_answer"]
    assert_not_nil revealed["scores"]
  end

  test "reveal ignored outside answering phase" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    # Still in reading phase
    before = broadcasts("trivia:#{@room.code}").size

    perform :reveal

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  test "phone cannot trigger reveal" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    unsubscribe

    subscribe code: @room.code, slot: 1
    before = broadcasts("trivia:#{@room.code}").size

    perform :reveal

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  # ── next_question ─────────────────────────────────────────────────────────

  test "next_question advances to next question and broadcasts" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    perform :reveal

    perform :next_question

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    q2 = msgs.select { |m| m["type"] == "question" }.last
    assert_not_nil q2
    assert_equal 1, q2["q_index"]
  end

  test "next_question after last question broadcasts game_over" do
    subscribe code: @room.code, role: "tv"
    perform :start_game

    # Manually wind session to last question
    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    session[:q_index] = session[:order].length - 1
    session[:phase]   = "revealed"
    TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] = session }

    perform :next_question

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    over = msgs.find { |m| m["type"] == "game_over" }
    assert_not_nil over
    assert_not_nil over["scores"]
  end

  test "phone cannot call next_question" do
    subscribe code: @room.code, role: "tv"
    perform :start_game
    perform :start_answering
    perform :reveal
    unsubscribe

    subscribe code: @room.code, slot: 1
    before = broadcasts("trivia:#{@room.code}").size

    perform :next_question

    assert_equal before, broadcasts("trivia:#{@room.code}").size
  end

  # ── Full round-trip: question → answering → reveal → next ────────────────

  test "full question round-trip with two players scoring" do
    subscribe code: @room.code, role: "tv"
    perform :start_game

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    q = TriviaChannel::QUESTIONS[session[:order][0]]

    perform :start_answering
    unsubscribe

    # P1 answers correctly, P2 answers wrongly
    subscribe code: @room.code, slot: 1
    perform :answer, "index" => q[:answer]
    unsubscribe

    subscribe code: @room.code, slot: 2
    perform :answer, "index" => (q[:answer] + 1) % 4
    unsubscribe

    msgs = broadcasts("trivia:#{@room.code}").map { |m| JSON.parse(m) }
    revealed = msgs.find { |m| m["type"] == "revealed" }
    assert_not_nil revealed

    p1_result = revealed["results"].find { |r| r["slot"] == 1 }
    p2_result = revealed["results"].find { |r| r["slot"] == 2 }
    assert p1_result["correct"],  "P1 should be correct"
    assert_not p2_result["correct"], "P2 should be wrong"

    session = TriviaChannel::SESSIONS_MU.synchronize { TriviaChannel::SESSIONS[@room.code] }
    assert_equal 1, session[:scores]["1"]
    assert_nil session[:scores]["2"]
  end
end
