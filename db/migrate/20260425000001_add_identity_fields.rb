class AddIdentityFields < ActiveRecord::Migration[8.1]
  def change
    # Players: persistent device identity + make pin optional at DB level
    add_column :players, :device_token, :string
    add_index  :players, :device_token, unique: true, where: "device_token IS NOT NULL"
    change_column_null :players, :pin_digest, true

    # Rooms: tv_token for QR/ActionCable auth (separate from human-readable code)
    add_column :rooms, :tv_token, :string
    add_index  :rooms, :tv_token, unique: true, where: "tv_token IS NOT NULL"

    # Increase room TTL to 4 hours (update DEFAULT_TTL in model, not in migration)

    # RoomMemberships: device_token to track which device holds a slot
    add_column :room_memberships, :device_token, :string
    add_index  :room_memberships, :device_token
  end
end
