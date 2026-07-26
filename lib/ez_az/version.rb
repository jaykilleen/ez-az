module EzAz
  # Written by bin/release, which takes COMMIT straight from git. Do not patch
  # this file with sed -- a pattern that does not match fails silently, which
  # is how COMMIT drifted five releases behind on 2026-07-26. VersionTest
  # guards against it recurring.
  #
  # COMMIT is the commit the release was cut from, so it is the one
  # immediately before the "Release ..." commit that carries this file.
  module Version
    STRING = "20260726.15"
    COMMIT = "c8eda07"
  end
end
