class NormaliseInheritedSchema < ActiveRecord::Migration[8.1]
  def up
    counter_columns = connection.columns(:counters).map(&:name)

    # Old Rack schema had `key TEXT PRIMARY KEY` with no `id` column.
    # Recreate with Rails conventions while preserving existing data.
    unless counter_columns.include?("id")
      existing = connection.execute("SELECT key, value FROM counters")
      drop_table :counters
      create_table :counters do |t|
        t.string  :key,   null: false
        t.integer :value, null: false, default: 0
      end
      add_index :counters, :key, unique: true
      existing.each do |row|
        connection.execute(
          "INSERT INTO counters (key, value) VALUES (?, ?)",
          [row["key"], row["value"]]
        )
      end
    end

    # Old Rack schema had no `updated_at` column on scores.
    score_columns = connection.columns(:scores).map(&:name)
    unless score_columns.include?("updated_at")
      add_column :scores, :updated_at, :datetime
      execute("UPDATE scores SET updated_at = created_at")
    end

    # Seed visitor counter from JSON file if the DB counter is still 0.
    counter_file = Rails.root.join("data", "counter.json")
    if counter_file.exist?
      current = connection.select_value("SELECT value FROM counters WHERE key = 'visitors'").to_i
      if current == 0
        old_count = JSON.parse(counter_file.read)["count"].to_i rescue 0
        if old_count > 0
          connection.execute(
            "UPDATE counters SET value = ? WHERE key = 'visitors'",
            [old_count]
          )
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
