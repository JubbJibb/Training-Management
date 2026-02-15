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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_120000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "attendee_promotions", force: :cascade do |t|
    t.integer "attendee_id", null: false
    t.datetime "created_at", null: false
    t.integer "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attendee_id"], name: "index_attendee_promotions_on_attendee_id"
    t.index ["promotion_id"], name: "index_attendee_promotions_on_promotion_id"
  end

  create_table "attendees", force: :cascade do |t|
    t.text "address"
    t.string "attendance_status", default: "No-show"
    t.text "billing_address"
    t.string "billing_name"
    t.string "company"
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.string "document_status"
    t.date "due_date"
    t.string "email", null: false
    t.string "invoice_no"
    t.string "name", null: false
    t.string "name_thai"
    t.text "notes"
    t.string "participant_type", default: "Indi"
    t.date "payment_date"
    t.string "payment_status", default: "Pending"
    t.string "phone"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.string "quotation_no"
    t.string "receipt_no"
    t.integer "seats", default: 1, null: false
    t.string "source_channel"
    t.string "status", default: "attendee"
    t.string "tax_id"
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "total_classes", default: 0
    t.integer "training_class_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_attendees_on_customer_id"
    t.index ["email", "training_class_id"], name: "index_attendees_on_email_and_training_class_id", unique: true
    t.index ["training_class_id"], name: "index_attendees_on_training_class_id"
  end

  create_table "class_expenses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "training_class_id", null: false
    t.datetime "updated_at", null: false
    t.index ["training_class_id"], name: "index_class_expenses_on_training_class_id"
  end

  create_table "courses", force: :cascade do |t|
    t.integer "capacity"
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "duration_text"
    t.string "external_id"
    t.string "source_url"
    t.datetime "synced_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_courses_on_external_id"
    t.index ["title"], name: "index_courses_on_title"
  end

  create_table "custom_field_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "custom_field_id", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["custom_field_id"], name: "index_custom_field_values_on_custom_field_id"
    t.index ["record_type", "record_id", "custom_field_id"], name: "index_cfv_on_record_and_field", unique: true
  end

  create_table "custom_fields", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "entity_type", null: false
    t.string "field_type", default: "string"
    t.string "key", null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "key"], name: "index_custom_fields_on_entity_type_and_key", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "acquisition_channel"
    t.text "address"
    t.text "billing_address"
    t.string "billing_name"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "name_thai"
    t.string "participant_type"
    t.string "phone"
    t.string "tax_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
    t.index ["tax_id"], name: "index_customers_on_tax_id"
  end

  create_table "export_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "export_type", null: false
    t.string "filename"
    t.json "filters", default: {}
    t.datetime "finished_at"
    t.string "format", null: false
    t.boolean "include_custom_fields", default: false
    t.json "include_sections", default: {}
    t.integer "requested_by_id"
    t.datetime "started_at"
    t.string "state", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_export_jobs_on_requested_by_id"
  end

  create_table "financial_action_logs", force: :cascade do |t|
    t.string "action_type", null: false
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "metadata"
    t.string "status", default: "queued", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_financial_action_logs_on_action_type"
    t.index ["actor_id"], name: "index_financial_action_logs_on_actor_id"
    t.index ["created_at"], name: "index_financial_action_logs_on_created_at"
    t.index ["status"], name: "index_financial_action_logs_on_status"
    t.index ["subject_type", "subject_id"], name: "index_financial_action_logs_on_subject_type_and_subject_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.boolean "active", default: true
    t.decimal "base_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, default: "0.0"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "training_classes", force: :cascade do |t|
    t.decimal "cost", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description"
    t.date "end_date"
    t.time "end_time"
    t.string "instructor"
    t.string "location", null: false
    t.integer "max_attendees"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.time "start_time"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendee_promotions", "attendees"
  add_foreign_key "attendee_promotions", "promotions"
  add_foreign_key "attendees", "customers"
  add_foreign_key "attendees", "training_classes"
  add_foreign_key "class_expenses", "training_classes"
  add_foreign_key "custom_field_values", "custom_fields"
  add_foreign_key "export_jobs", "admin_users", column: "requested_by_id"
end
