# frozen_string_literal: true

# Database Redesign: Normalize to 13+ tables.
# - Creates: instructors, class_pricing, attendances, payments, documents, promotion_applications
# - Migrates data from attendees -> attendances + payments + documents + promotion_applications
# - Adds FKs and indexes; drops deprecated columns and old attendees/attendee_promotions.
#
# IMPORTANT: After running this migration, update the application to use:
# - Attendance (instead of Attendee), Payment, Document, PromotionApplication, Instructor, ClassPricing.
# - Customer: use first_name, last_name, company_name, province (name/company kept for backward compat in this migration).
#
# This file is stored in docs/migrations/ so it is NOT run by bin/rails db:migrate.
# Move it to db/migrate/ only when the app has been updated to the new schema.
class NormalizeDatabaseSchema < ActiveRecord::Migration[8.1]
  def up
    # ========== Step 1: Create new tables ==========

    create_instructors
    create_class_pricing
    create_attendances
    create_payments
    create_documents
    ensure_promotions_columns
    create_promotion_applications

    # ========== Step 2: Add new columns to existing tables ==========

    add_new_columns_to_customers
    add_new_columns_to_training_classes

    # ========== Step 3: Data migration ==========

    backfill_instructors
    backfill_class_pricing
    backfill_customers_name_and_address
    backfill_attendances_and_related
    backfill_promotion_applications
    backfill_promotions_type

    # ========== Step 4: Foreign keys & indexes ==========

    add_foreign_keys_and_indexes

    # ========== Step 5: Clean up old structure ==========

    drop_deprecated_columns_and_tables

    # ========== Validation ==========

    validate_migration
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "NormalizeDatabaseSchema: manual rollback recommended (restore DB from backup)."
  end

  private

  def create_instructors
    create_table :instructors do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.text :bio
      t.decimal :rate, precision: 10, scale: 2
      t.timestamps
    end
  end

  def create_class_pricing
    create_table :class_pricing do |t|
      t.references :training_class, null: false, index: { unique: true }
      t.decimal :base_price, precision: 10, scale: 2, default: 0
      t.decimal :vat_rate, precision: 5, scale: 4, default: 0.07
      t.decimal :early_bird_price, precision: 10, scale: 2
      t.date :early_bird_deadline
      t.string :currency, default: "THB"
      t.datetime :created_at, null: false
    end
  end

  def create_attendances
    create_table :attendances do |t|
      t.references :training_class, null: false, index: true
      t.references :customer, null: false, index: true
      t.string :participant_type, default: "Indi"
      t.integer :seats, default: 1, null: false
      t.string :source_channel
      t.string :status, default: "attendee"
      t.date :attendance_date
      t.text :notes
      t.timestamps
    end
    add_index :attendances, %i[training_class_id customer_id], unique: true, name: "index_attendances_on_tc_and_customer"
  end

  def create_payments
    create_table :payments do |t|
      t.references :attendance, null: false, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.string :payment_method
      t.date :payment_date
      t.string :payment_status, default: "Pending"
      t.string :invoice_number
      t.string :receipt_number
      t.date :due_date
      t.timestamps
    end
  end

  def create_documents
    create_table :documents do |t|
      t.references :attendance, null: false, index: true
      t.string :document_type, null: false
      t.string :file_key
      t.string :file_name
      t.datetime :created_at, null: false
    end
  end

  def ensure_promotions_columns
    return unless table_exists?(:promotions)
    add_column :promotions, :promotion_type, :string unless column_exists?(:promotions, :promotion_type)
    add_column :promotions, :discount_percentage, :decimal, precision: 5, scale: 2 unless column_exists?(:promotions, :discount_percentage)
    add_column :promotions, :max_uses, :integer unless column_exists?(:promotions, :max_uses)
    add_column :promotions, :start_date, :date unless column_exists?(:promotions, :start_date)
    add_column :promotions, :end_date, :date unless column_exists?(:promotions, :end_date)
  end

  def create_promotion_applications
    create_table :promotion_applications do |t|
      t.references :attendance, null: false, index: true
      t.references :promotion, null: false, index: true
      t.decimal :discount_amount, precision: 10, scale: 2
      t.date :applied_date, null: false
    end
  end

  def add_new_columns_to_customers
    return unless table_exists?(:customers)
    add_column :customers, :first_name, :string unless column_exists?(:customers, :first_name)
    add_column :customers, :last_name, :string unless column_exists?(:customers, :last_name)
    add_column :customers, :company_name, :string unless column_exists?(:customers, :company_name)
    add_column :customers, :province, :string unless column_exists?(:customers, :province)
  end

  def add_new_columns_to_training_classes
    return unless table_exists?(:training_classes)
    add_reference :training_classes, :instructor, index: true unless column_exists?(:training_classes, :instructor_id)
    add_column :training_classes, :status, :string, default: "scheduled" unless column_exists?(:training_classes, :status)
    add_column :training_classes, :start_date, :date unless column_exists?(:training_classes, :start_date)
  end

  def backfill_instructors
    return unless table_exists?(:training_classes) && table_exists?(:instructors)
    return unless column_exists?(:training_classes, :instructor)
    seen = {}
    connection.select_all("SELECT id, instructor FROM training_classes WHERE instructor IS NOT NULL AND instructor != ''").each do |row|
      id = row["id"]
      name = row["instructor"].to_s.strip
      next if name.blank?
      key = name.downcase
      unless seen[key]
        inst_id = insert_instructor(name)
        seen[key] = inst_id if inst_id
      end
      connection.execute("UPDATE training_classes SET instructor_id = #{seen[key]} WHERE id = #{id}") if seen[key]
    end
    if column_exists?(:training_classes, :date)
      connection.execute("UPDATE training_classes SET start_date = date WHERE start_date IS NULL AND date IS NOT NULL")
    end
  end

  def insert_instructor(name)
    parts = name.to_s.strip.split(/\s+/, 2)
    first_name = parts[0].presence || "Instructor"
    last_name = parts[1].presence || ""
    now = quote(Time.current)
    connection.execute(<<~SQL)
      INSERT INTO instructors (first_name, last_name, created_at, updated_at) VALUES (#{quote(first_name)}, #{quote(last_name)}, #{now}, #{now})
    SQL
    connection.select_value("SELECT last_insert_rowid()").to_i
  end

  def backfill_class_pricing
    return unless table_exists?(:class_pricing) && table_exists?(:training_classes)
    return unless column_exists?(:training_classes, :price)
    connection.execute(<<~SQL)
      INSERT INTO class_pricing (training_class_id, base_price, vat_rate, currency, created_at)
      SELECT id, COALESCE(price, 0), 0.07, 'THB', datetime('now') FROM training_classes
    SQL
  end

  def backfill_customers_name_and_address
    return unless table_exists?(:customers)
    return unless column_exists?(:customers, :name)
    connection.select_all("SELECT id, name, company, address FROM customers").each do |c|
      name = (c["name"] || "").to_s.strip
      parts = name.split(/\s+/, 2)
      first_name = parts[0].presence || "Customer"
      last_name = parts[1].presence || ""
      company_name = (c["company"] || "").to_s.strip.presence
      id = c["id"]
      connection.execute(<<~SQL)
        UPDATE customers SET first_name = #{quote(first_name)}, last_name = #{quote(last_name)}, company_name = #{quote(company_name)}, province = NULL WHERE id = #{id}
      SQL
    end
  end

  def backfill_attendances_and_related
    return unless table_exists?(:attendees) && table_exists?(:attendances)
    connection.select_all("SELECT * FROM attendees ORDER BY id").each do |a|
      tc_id = a["training_class_id"]
      cust_id = a["customer_id"]
      if cust_id.blank? && a["email"].present?
        cust = connection.select_all("SELECT id FROM customers WHERE email = #{quote(a["email"])}").first
        cust_id = cust&.dig("id")
        if cust_id.blank?
          fn = (a["name"] || "").to_s.strip.split(/\s+/, 2)[0] || "Customer"
          ln = (a["name"] || "").to_s.strip.split(/\s+/, 2)[1] || ""
          connection.execute(<<~SQL)
            INSERT INTO customers (name, email, created_at, updated_at, first_name, last_name)
            VALUES (#{quote(a["name"])}, #{quote(a["email"])}, datetime('now'), datetime('now'), #{quote(fn)}, #{quote(ln)})
          SQL
          cust_id = connection.select_value("SELECT last_insert_rowid()").to_i
        end
        connection.execute("UPDATE attendees SET customer_id = #{cust_id} WHERE id = #{a["id"]}")
      end
      next if cust_id.blank?

      attendance_date = a["created_at"].is_a?(String) ? Time.zone.parse(a["created_at"])&.to_date : (a["created_at"]&.to_date)
      attendance_date ||= Date.current

      connection.execute(<<~SQL)
        INSERT INTO attendances (training_class_id, customer_id, participant_type, seats, source_channel, status, attendance_date, notes, created_at, updated_at)
        VALUES (#{tc_id}, #{cust_id}, #{quote(a["participant_type"] || "Indi")}, #{a["seats"] || 1}, #{quote(a["source_channel"])}, #{quote(a["status"] || "attendee")}, #{quote(attendance_date)}, #{quote(a["notes"])}, #{quote(a["created_at"])}, #{quote(a["updated_at"])})
      SQL
      att_id = connection.select_value("SELECT last_insert_rowid()").to_i

      amount = a["total_amount"] || a["price"] || 0
      connection.execute(<<~SQL)
        INSERT INTO payments (attendance_id, amount, payment_status, invoice_number, receipt_number, due_date, created_at, updated_at)
        VALUES (#{att_id}, #{amount}, #{quote(a["payment_status"] || "Pending")}, #{quote(a["invoice_no"])}, #{quote(a["receipt_no"])}, #{quote(a["due_date"])}, #{quote(a["created_at"])}, #{quote(a["updated_at"])})
      SQL

      if a["document_status"].present?
        connection.execute(<<~SQL)
          INSERT INTO documents (attendance_id, document_type, created_at) VALUES (#{att_id}, #{quote(a["document_status"])}, #{quote(a["created_at"])})
        SQL
      end
    end
  end

  def backfill_promotion_applications
    return unless table_exists?(:attendee_promotions) && table_exists?(:promotion_applications)
    return unless table_exists?(:attendances)
    att_map = {}
    connection.select_all("SELECT id, training_class_id, customer_id FROM attendances").each do |row|
      key = "#{row["training_class_id"]}_#{row["customer_id"]}"
      att_map[key] = row["id"]
    end
    connection.select_all("SELECT attendee_id, promotion_id FROM attendee_promotions").each do |row|
      att_old = connection.select_all("SELECT training_class_id, customer_id FROM attendees WHERE id = #{row["attendee_id"]}").first
      next unless att_old
      key = "#{att_old["training_class_id"]}_#{att_old["customer_id"]}"
      att_id = att_map[key]
      next unless att_id
      connection.execute(<<~SQL)
        INSERT INTO promotion_applications (attendance_id, promotion_id, applied_date, discount_amount) VALUES (#{att_id}, #{row["promotion_id"]}, date('now'), 0)
      SQL
    end
  end

  def backfill_promotions_type
    return unless table_exists?(:promotions) && column_exists?(:promotions, :promotion_type) && column_exists?(:promotions, :discount_type)
    connection.execute("UPDATE promotions SET promotion_type = discount_type WHERE promotion_type IS NULL AND discount_type IS NOT NULL")
  end

  def add_foreign_keys_and_indexes
    add_foreign_key :class_pricing, :training_classes, on_delete: :cascade if table_exists?(:class_pricing)
    add_foreign_key :attendances, :training_classes, on_delete: :cascade if table_exists?(:attendances)
    add_foreign_key :attendances, :customers, on_delete: :nullify if table_exists?(:attendances)
    add_foreign_key :payments, :attendances, on_delete: :cascade if table_exists?(:payments)
    add_foreign_key :documents, :attendances, on_delete: :cascade if table_exists?(:documents)
    add_foreign_key :promotion_applications, :attendances, on_delete: :cascade if table_exists?(:promotion_applications)
    add_foreign_key :promotion_applications, :promotions, on_delete: :cascade if table_exists?(:promotion_applications)
    add_foreign_key :training_classes, :instructors, on_delete: :nullify if column_exists?(:training_classes, :instructor_id)
  end

  def drop_deprecated_columns_and_tables
    if table_exists?(:attendee_promotions)
      remove_foreign_key :attendee_promotions, :attendees if foreign_key_exists?(:attendee_promotions, :attendees)
      remove_foreign_key :attendee_promotions, :promotions if foreign_key_exists?(:attendee_promotions, :promotions)
      drop_table :attendee_promotions
    end
    if table_exists?(:attendees)
      remove_foreign_key :attendees, :training_classes if foreign_key_exists?(:attendees, :training_classes)
      remove_foreign_key :attendees, :customers if foreign_key_exists?(:attendees, :customers)
      drop_table :attendees
    end
    if table_exists?(:training_classes)
      remove_column :training_classes, :instructor if column_exists?(:training_classes, :instructor)
      remove_column :training_classes, :price if column_exists?(:training_classes, :price)
      remove_column :training_classes, :date if column_exists?(:training_classes, :date)
    end
  end

  def validate_migration
    return unless table_exists?(:attendances)
    count_attendances = connection.select_value("SELECT COUNT(*) FROM attendances").to_i
    count_payments = connection.select_value("SELECT COUNT(*) FROM payments").to_i
    return if count_attendances.zero?
    raise "Validation failed: payments (#{count_payments}) < attendances (#{count_attendances})" if count_payments < count_attendances
  end

  def quote(val)
    return "NULL" if val.nil?
    connection.quote(val)
  end
end
