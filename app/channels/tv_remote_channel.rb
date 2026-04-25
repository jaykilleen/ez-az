class TvRemoteChannel < ApplicationCable::Channel
  ALLOWED = %w[left right up down select back].freeze

  def subscribed
    token = clean_token
    return reject if token.blank?
    stream_from "tv_remote:#{token}"
  end

  def navigate(data)
    dir = data["direction"].to_s
    return unless ALLOWED.include?(dir)
    ActionCable.server.broadcast("tv_remote:#{clean_token}", { type: "navigate", direction: dir })
  end

  private

  def clean_token
    params[:token].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
  end
end
