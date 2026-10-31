# Injects shared scripts into every /games/*.html response so individual game
# files never need to know about them. Any new shared script goes here, not
# into 16+ game files.
class GameScriptInjector
  SCRIPTS = %w[/ez-az-bug-report.js].freeze

  INJECTION = SCRIPTS.map { |s| %(<script src="#{s}"></script>) }.join("\n")
  GAME_PATH = %r{\A/games/[^/]+\.html\z}

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if status == 200 &&
       GAME_PATH.match?(env["PATH_INFO"]) &&
       (headers["content-type"] || "").include?("text/html")

      parts = []
      body.each { |chunk| parts << chunk }
      body.close if body.respond_to?(:close)

      html = parts.join.sub("</body>", "#{INJECTION}\n</body>")
      headers["content-length"] = html.bytesize.to_s
      body = [html]
    end

    [status, headers, body]
  end
end
