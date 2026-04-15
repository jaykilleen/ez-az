class CreateCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :counters, if_not_exists: true do |t|
      t.string :key, null: false
      t.integer :value, null: false, default: 0
    end

    add_index :counters, :key, unique: true
  end
end
