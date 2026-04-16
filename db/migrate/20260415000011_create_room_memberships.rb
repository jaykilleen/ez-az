class CreateRoomMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :room_memberships do |t|
      t.references :room,   null: false, foreign_key: true
      t.references :player, null: true,  foreign_key: true
      t.string  :name,       null: false, limit: 12
      t.integer :role,       null: false, default: 1  # 0=host, 1=player
      t.integer :slot,       null: false              # 1..4 — player number within the room
      t.boolean :connected,  null: false, default: true
      t.string  :session_id, null: true               # random per-browser ID so guests can rejoin
      t.timestamps
    end

    add_index :room_memberships, [:room_id, :slot],       unique: true
    add_index :room_memberships, [:room_id, :session_id], unique: true, where: "session_id IS NOT NULL"
  end
end
