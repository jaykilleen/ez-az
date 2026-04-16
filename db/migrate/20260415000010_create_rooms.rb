class CreateRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :rooms do |t|
      t.string   :code,       null: false
      t.string   :game_slug
      t.integer  :state,      null: false, default: 0  # 0=lobby, 1=playing, 2=finished
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :rooms, :code,       unique: true
    add_index :rooms, :expires_at
  end
end
