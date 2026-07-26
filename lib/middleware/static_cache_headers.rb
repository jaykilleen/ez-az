class StaticCacheHeaders
  # Shared code that every game depends on, and that must stay in lockstep with
  # the game HTML. The HTML is already no-cache, so caching these for an hour
  # lets a freshly deployed game run against an hour-old runtime -- which shows
  # up as newer ArcadeShell options being silently ignored, not as an error.
  #
  # no-cache still revalidates rather than refetching, so these come back as
  # 304s once warm. They are a few KB each; correctness is worth more here.
  ALWAYS_FRESH = %w[
    /ez-az-shell.css
    /arcade-shell.js
    /arcade-cable.js
    /arcade-tv.js
    /opening-hours.js
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    path = env["PATH_INFO"]

    # Determine which public file was served (handles / -> index.html)
    public_root = File.join(File.expand_path("../../public", __dir__))
    file_path = path == "/" ? File.join(public_root, "index.html") : File.join(public_root, path.delete_prefix("/"))

    if status == 200 && File.exist?(file_path) && !File.directory?(file_path)
      if File.extname(file_path) == ".html" || ALWAYS_FRESH.include?(path)
        headers["cache-control"] = "no-cache"
      else
        headers["cache-control"] = "public, max-age=3600"
      end
    end

    [status, headers, body]
  end
end
