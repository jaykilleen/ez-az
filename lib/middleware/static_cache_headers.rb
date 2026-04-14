class StaticCacheHeaders
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
      if File.extname(file_path) == ".html"
        headers["cache-control"] = "no-cache"
      else
        headers["cache-control"] = "public, max-age=3600"
      end
    end

    [status, headers, body]
  end
end
