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

ActiveRecord::Schema[8.1].define(version: 2026_03_31_120000) do
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

  create_table "attendance_record_attendees", force: :cascade do |t|
    t.integer "attendance_record_id", null: false
    t.integer "attendee_id", null: false
    t.datetime "created_at", null: false
    t.boolean "present", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["attendance_record_id", "attendee_id"], name: "index_ara_on_record_and_attendee", unique: true
    t.index ["attendance_record_id"], name: "index_attendance_record_attendees_on_attendance_record_id"
    t.index ["attendee_id"], name: "index_attendance_record_attendees_on_attendee_id"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.date "attendance_date", null: false
    t.datetime "created_at", null: false
    t.string "learning_hour", null: false
    t.integer "recorded_by_id"
    t.integer "training_class_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_by_id"], name: "index_attendance_records_on_recorded_by_id"
    t.index ["training_class_id", "attendance_date", "learning_hour"], name: "index_attendance_records_on_class_date_hour", unique: true
    t.index ["training_class_id"], name: "index_attendance_records_on_training_class_id"
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
    t.decimal "advance_paid_amount", precision: 12, scale: 2
    t.text "advance_paid_note"
    t.string "attendance_status", default: "No-show"
    t.text "billing_address"
    t.string "billing_name"
    t.decimal "bundle_discount_fixed", precision: 10, scale: 2
    t.decimal "bundle_discount_percent", precision: 5, scale: 2
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
    t.datetime "slip_verified_at"
    t.string "source_channel"
    t.string "status", default: "attendee"
    t.string "tax_id"
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "total_classes", default: 0
    t.integer "training_class_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "vat_excluded"
    t.index ["customer_id"], name: "index_attendees_on_customer_id"
    t.index ["due_date", "payment_status"], name: "index_attendees_on_due_date_and_payment_status"
    t.index ["email", "training_class_id"], name: "index_attendees_on_email_and_training_class_id", unique: true
    t.index ["training_class_id"], name: "index_attendees_on_training_class_id"
  end

  create_table "budget_allocations", force: :cascade do |t|
    t.decimal "allocated_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.integer "budget_category_id", null: false
    t.integer "budget_year_id", null: false
    t.datetime "created_at", null: false
    t.json "monthly_plan"
    t.datetime "updated_at", null: false
    t.index ["budget_category_id"], name: "index_budget_allocations_on_budget_category_id"
    t.index ["budget_year_id", "budget_category_id"], name: "index_budget_allocations_on_year_and_category", unique: true
    t.index ["budget_year_id"], name: "index_budget_allocations_on_budget_year_id"
  end

  create_table "budget_categories", force: :cascade do |t|
    t.string "code", null: false
    t.string "cost_type", default: "variable", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_budget_categories_on_code", unique: true
    t.index ["sort_order"], name: "index_budget_categories_on_sort_order"
  end

  create_table "budget_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "location"
    t.string "name", null: false
    t.text "notes"
    t.text "objective"
    t.string "organizer"
    t.string "owner_name"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["start_date"], name: "index_budget_events_on_start_date"
  end

  create_table "budget_expenses", force: :cascade do |t|
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.integer "budget_category_id", null: false
    t.integer "budget_year_id", null: false
    t.bigint "campaign_id"
    t.bigint "class_id"
    t.datetime "created_at", null: false
    t.date "expense_date", null: false
    t.text "notes"
    t.string "payment_method"
    t.string "payment_status", default: "planned", null: false
    t.string "reference_no"
    t.integer "sponsorship_deal_id"
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["budget_category_id"], name: "index_budget_expenses_on_budget_category_id"
    t.index ["budget_year_id", "budget_category_id"], name: "index_budget_expenses_on_budget_year_id_and_budget_category_id"
    t.index ["budget_year_id", "expense_date"], name: "index_budget_expenses_on_budget_year_id_and_expense_date"
    t.index ["budget_year_id", "payment_status"], name: "index_budget_expenses_on_budget_year_id_and_payment_status"
    t.index ["budget_year_id"], name: "index_budget_expenses_on_budget_year_id"
    t.index ["expense_date"], name: "index_budget_expenses_on_expense_date"
    t.index ["sponsorship_deal_id"], name: "index_budget_expenses_on_sponsorship_deal_id"
  end

  create_table "budget_staff_monthly_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "month", null: false
    t.text "notes"
    t.decimal "planned_days", precision: 6, scale: 2
    t.integer "staff_profile_id", null: false
    t.string "status", default: "planned", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["staff_profile_id", "year", "month"], name: "index_staff_monthly_plans_on_profile_year_month", unique: true
    t.index ["staff_profile_id"], name: "index_budget_staff_monthly_plans_on_staff_profile_id"
    t.index ["year", "month"], name: "index_budget_staff_monthly_plans_on_year_and_month"
  end

  create_table "budget_staff_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.date "effective_from"
    t.string "email"
    t.date "end_date"
    t.decimal "internal_day_rate", precision: 14, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.string "nickname"
    t.string "phone"
    t.string "role"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["department", "status"], name: "index_budget_staff_profiles_on_department_and_status"
    t.index ["status"], name: "index_budget_staff_profiles_on_status"
  end

  create_table "budget_staff_worklogs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "linked_id"
    t.string "linked_type"
    t.decimal "mandays", precision: 4, scale: 2, default: "1.0", null: false
    t.text "notes"
    t.integer "staff_profile_id", null: false
    t.datetime "updated_at", null: false
    t.date "work_date", null: false
    t.index ["linked_type", "linked_id"], name: "index_budget_staff_worklogs_on_linked_type_and_linked_id"
    t.index ["staff_profile_id", "work_date"], name: "index_budget_staff_worklogs_on_staff_profile_id_and_work_date"
    t.index ["staff_profile_id"], name: "index_budget_staff_worklogs_on_staff_profile_id"
    t.index ["work_date"], name: "index_budget_staff_worklogs_on_work_date"
  end

  create_table "budget_years", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "owner_name"
    t.string "status", default: "draft", null: false
    t.decimal "total_budget", precision: 14, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["status"], name: "index_budget_years_on_status"
    t.index ["year"], name: "index_budget_years_on_year", unique: true
  end

  create_table "class_expenses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.date "expense_date"
    t.boolean "is_estimated", default: false, null: false
    t.string "payment_status", default: "unpaid"
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

  create_table "sponsorship_deals", force: :cascade do |t|
    t.decimal "amount", precision: 14, scale: 2, default: "0.0"
    t.text "benefits"
    t.datetime "created_at", null: false
    t.date "deliverables_due_date"
    t.integer "event_id", null: false
    t.text "notes"
    t.string "status", default: "planned", null: false
    t.string "tier"
    t.datetime "updated_at", null: false
    t.index ["event_id", "status"], name: "index_sponsorship_deals_on_event_id_and_status"
    t.index ["event_id"], name: "index_sponsorship_deals_on_event_id"
    t.index ["status"], name: "index_sponsorship_deals_on_status"
  end

  create_table "training_classes", force: :cascade do |t|
    t.text "checklist_items", default: "[]"
    t.string "class_status", default: "private", null: false
    t.decimal "cost", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description"
    t.date "end_date"
    t.time "end_time"
    t.string "instructor"
    t.text "internal_notes"
    t.datetime "internal_notes_updated_at"
    t.bigint "internal_notes_updated_by_id"
    t.string "location", null: false
    t.integer "max_attendees"
    t.text "notes", default: "[]"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.boolean "public_enabled", default: false, null: false
    t.string "public_slug"
    t.text "related_links", default: "[]"
    t.time "start_time"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.boolean "vat_excluded", default: false, null: false
    t.index ["public_slug"], name: "index_training_classes_on_public_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendance_record_attendees", "attendance_records"
  add_foreign_key "attendance_record_attendees", "attendees"
  add_foreign_key "attendance_records", "admin_users", column: "recorded_by_id"
  add_foreign_key "attendance_records", "training_classes"
  add_foreign_key "attendee_promotions", "attendees"
  add_foreign_key "attendee_promotions", "promotions"
  add_foreign_key "attendees", "customers"
  add_foreign_key "attendees", "training_classes"
  add_foreign_key "budget_allocations", "budget_categories"
  add_foreign_key "budget_allocations", "budget_years"
  add_foreign_key "budget_expenses", "budget_categories"
  add_foreign_key "budget_expenses", "budget_years"
  add_foreign_key "budget_expenses", "sponsorship_deals"
  add_foreign_key "budget_staff_monthly_plans", "budget_staff_profiles", column: "staff_profile_id"
  add_foreign_key "budget_staff_worklogs", "budget_staff_profiles", column: "staff_profile_id"
  add_foreign_key "class_expenses", "training_classes"
  add_foreign_key "custom_field_values", "custom_fields"
  add_foreign_key "export_jobs", "admin_users", column: "requested_by_id"
  add_foreign_key "sponsorship_deals", "budget_events", column: "event_id"
  add_foreign_key "training_classes", "admin_users", column: "internal_notes_updated_by_id", on_delete: :nullify
end
