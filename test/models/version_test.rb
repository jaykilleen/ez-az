require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"

# /api/version is the post-deploy signal for every release, so a malformed or
# stale value there is worse than useless -- it reports success against the
# wrong thing.
#
# COMMIT drifted five releases behind on 2026-07-26 because the version file
# was being patched with sed against a guessed previous value; when the guess
# was wrong, sed silently changed nothing. Use bin/release, which rewrites the
# file wholesale and takes COMMIT from git.
class VersionTest < ActiveSupport::TestCase
  test "STRING is a date-stamped build number" do
    assert_match(/\A\d{8}\.\d+\z/, EzAz::Version::STRING,
      "expected YYYYMMDD.N, got #{EzAz::Version::STRING.inspect}")
  end

  test "STRING carries a real date" do
    date = EzAz::Version::STRING.split(".").first
    parsed = begin
      Date.strptime(date, "%Y%m%d")
    rescue ArgumentError
      nil
    end
    assert parsed, "#{date} is not a valid date"
  end

  test "COMMIT looks like an abbreviated git SHA" do
    assert_match(/\A[0-9a-f]{7,40}\z/, EzAz::Version::COMMIT,
      "expected a short SHA, got #{EzAz::Version::COMMIT.inspect}")
  end

  # The endpoint the deploy poller reads. If its shape changes, every deploy
  # check that greps for "version" stops working.
  test "the version endpoint reports both fields" do
    get_via_rack = ActionDispatch::Integration::Session.new(Rails.application)
    get_via_rack.get "/api/version"

    assert_equal 200, get_via_rack.response.status
    body = JSON.parse(get_via_rack.response.body)
    assert_equal EzAz::Version::STRING, body["version"]
    assert_equal EzAz::Version::COMMIT, body["commit"]
  end

  # Guard: bin/release must abort with a clear error when STRING is malformed
  # rather than silently resetting the build counter to 1 via bad arithmetic.
  test "bin/release aborts with a clear error when STRING is malformed" do
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "lib/ez_az"))
      File.write(File.join(tmp, "lib/ez_az/version.rb"), <<~RUBY)
        module EzAz
          module Version
            STRING = "bad-version"
            COMMIT = "abc1234"
          end
        end
      RUBY

      script = Rails.root.join("bin/release").to_s
      out, status = Open3.capture2e(script, chdir: tmp)

      assert_not status.success?, "expected bin/release to exit non-zero on malformed STRING"
      assert_match(/does not match expected YYYYMMDD\.N format/, out)
    end
  end

  # Only meaningful with real git history. CI checks out shallow, so skip there
  # rather than fail on a missing object.
  test "COMMIT points at a commit that actually exists" do
    skip "no .git directory" unless Rails.root.join(".git").exist?

    sha = EzAz::Version::COMMIT
    exists = system("git", "cat-file", "-e", "#{sha}^{commit}",
                    chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
    skip "shallow clone, #{sha} not present locally" unless exists

    behind = `git rev-list #{sha}..HEAD --count 2>/dev/null`.strip.to_i
    assert_operator behind, :<=, 3,
      "Version::COMMIT (#{sha}) is #{behind} commits behind HEAD. It should be " \
      "the commit the release was cut from. Use bin/release rather than editing " \
      "lib/ez_az/version.rb by hand."
  end
end
