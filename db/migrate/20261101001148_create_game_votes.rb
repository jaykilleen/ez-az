class CreateGameVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_votes do |t|
      t.references :player, null: false, foreign_key: true
      t.string :game_slug, null: false

      t.timestamps
    end
    add_index :game_votes, [:player_id, :game_slug], unique: true
  end
end
