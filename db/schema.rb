# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_15_000011) do
  create_table "counters", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 0, null: false
    t.index ["key"], name: "index_counters_on_key", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.string "pin_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_players_on_username", unique: true
  end

  create_table "room_memberships", force: :cascade do |t|
    t.boolean "connected", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 12, null: false
    t.integer "player_id"
    t.integer "role", default: 1, null: false
    t.integer "room_id", null: false
    t.string "session_id"
    t.integer "slot", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_room_memberships_on_player_id"
    t.index ["room_id", "session_id"], name: "index_room_memberships_on_room_id_and_session_id", unique: true, where: "session_id IS NOT NULL"
    t.index ["room_id", "slot"], name: "index_room_memberships_on_room_id_and_slot", unique: true
    t.index ["room_id"], name: "index_room_memberships_on_room_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "game_slug"
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["expires_at"], name: "index_rooms_on_expires_at"
  end

  create_table "scores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game", null: false
    t.string "name", null: false
    t.integer "player_id"
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["game"], name: "index_scores_on_game"
    t.index ["player_id"], name: "index_scores_on_player_id"
  end

  add_foreign_key "room_memberships", "players"
  add_foreign_key "room_memberships", "rooms"
  add_foreign_key "scores", "players"
end
