class CreateScores < ActiveRecord::Migration[8.0]
  def change
    create_table :scores do |t|
      t.string :game, null: false
      t.string :name, null: false
      t.integer :value, null: false
      t.timestamps
    end

    add_index :scores, :game
  end
end
