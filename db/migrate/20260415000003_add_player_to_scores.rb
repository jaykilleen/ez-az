class AddPlayerToScores < ActiveRecord::Migration[8.1]
  def change
    add_reference :scores, :player, null: true, foreign_key: true
  end
end
