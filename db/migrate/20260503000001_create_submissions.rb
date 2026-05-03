class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.string  :slug,            null: false
      t.string  :title,           null: false
      t.string  :creators,        null: false
      t.string  :tagline,         null: false
      t.string  :score_direction, null: false, default: "desc"
      t.boolean :is_chill,        null: false, default: false
      t.text    :game_html,       null: false
      t.string  :contact_email,   null: false
      t.text    :notes
      t.string  :status,          null: false, default: "pending"
      t.text    :reviewer_notes
      t.string  :submitter_ip
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :submissions, :status
    add_index :submissions, :slug
    add_index :submissions, :created_at
  end
end
