class AddDisconnectedAtToRoomMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :room_memberships, :disconnected_at, :datetime
  end
end
