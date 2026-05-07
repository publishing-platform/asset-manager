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

ActiveRecord::Schema[8.1].define(version: 2026_05_07_134559) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assets", force: :cascade do |t|
    t.jsonb "auth_bypass_ids", default: [], null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.datetime "deleted_at", precision: nil
    t.boolean "draft", default: false, null: false
    t.string "etag"
    t.jsonb "filename_history", default: [], null: false
    t.datetime "last_modified", precision: nil
    t.string "md5_hexdigest"
    t.string "parent_document_url"
    t.string "redirect_url"
    t.bigint "replaced_by_id"
    t.integer "size"
    t.string "state", default: "unscanned", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["deleted_at"], name: "index_assets_on_deleted_at"
    t.index ["replaced_by_id"], name: "index_assets_on_replaced_by_id"
    t.index ["uuid"], name: "index_assets_on_uuid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "disabled", default: false
    t.string "email"
    t.string "name"
    t.string "organisation_content_id"
    t.string "organisation_slug"
    t.text "permissions"
    t.string "uid"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "assets", "assets", column: "replaced_by_id", on_delete: :restrict
end
