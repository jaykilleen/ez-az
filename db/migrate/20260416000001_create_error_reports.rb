class CreateErrorReports < ActiveRecord::Migration[8.0]
  def change
    create_table :error_reports do |t|
      t.string   :fingerprint,    null: false
      t.string   :message,        null: false, limit: 500
      t.text     :stack
      t.string   :game
      t.string   :user_agent,     limit: 500
      t.string   :url,            limit: 500
      t.integer  :occurrences,    null: false, default: 1
      t.datetime :first_seen_at,  null: false
      t.datetime :last_seen_at,   null: false
      t.timestamps
    end

    add_index :error_reports, :fingerprint,   unique: true
    add_index :error_reports, :last_seen_at
    add_index :error_reports, :game
  end
end
