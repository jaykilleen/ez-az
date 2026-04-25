class Api::WatchController < ApplicationController
  def position
    player = Player.find_by(device_token: params[:device_token].to_s.gsub(/[^a-zA-Z0-9]/, "")[0, 64])
    return render json: {} unless player
    render json: { track_slug: player.watch_track_slug, video_index: player.watch_video_index || 0 }
  end

  def update_position
    device_token = params[:device_token].to_s.gsub(/[^a-zA-Z0-9]/, "")[0, 64]
    player       = Player.find_by(device_token: device_token)
    return head :unauthorized unless player

    player.update_columns(
      watch_track_slug:  params[:track_slug].to_s[0, 40].presence,
      watch_video_index: params[:video_index].to_i.clamp(0, 999)
    )
    head :ok
  end
end
