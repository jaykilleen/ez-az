class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string   :username,         null: false
      t.string   :pin_digest,       null: false
      t.integer  :failed_attempts,  null: false, default: 0
      t.datetime :locked_until

      t.timestamps
    end

    add_index :players, :username, unique: true
  end
end
