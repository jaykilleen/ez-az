class AddKindAndIdeaPromptToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :kind, :string, default: "html", null: false
    add_column :submissions, :idea_prompt, :text
    add_index :submissions, :kind

    # A "prompt" submission has no code yet -- these three only make sense
    # once an actual game exists.
    change_column_null :submissions, :game_html, true
    change_column_null :submissions, :slug, true
    change_column_null :submissions, :tagline, true
  end
end
