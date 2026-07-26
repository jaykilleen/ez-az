module EzAz
  # COMMIT is the last substantive commit, not the release commit that carries
  # this file -- the release commit is always the one immediately after it.
  # /api/version reporting a SHA one behind HEAD is expected, not a bug.
  module Version
    STRING = "20260726.6"
    COMMIT = "cee0f2e"
  end
end
