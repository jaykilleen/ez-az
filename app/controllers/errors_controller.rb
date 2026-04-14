class ErrorsController < ApplicationController
  def not_found
    render html: '<h1>404 - Game not found</h1><p><a href="/">Back to EZ-AZ</a></p>'.html_safe,
           status: :not_found, content_type: "text/html"
  end

  def internal_error
    render html: "<h1>500 - Something went wrong</h1>".html_safe,
           status: :internal_server_error, content_type: "text/html"
  end
end
