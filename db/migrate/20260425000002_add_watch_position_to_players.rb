class AddWatchPositionToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :watch_track_slug,  :string
    add_column :players, :watch_video_index, :integer, default: 0, null: false
  end
end
