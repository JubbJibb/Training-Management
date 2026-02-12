# frozen_string_literal: true

class CreateExportSystemTables < ActiveRecord::Migration[8.1]
  def change
    create_table :export_jobs do |t|
      t.string :state, null: false, default: "queued"
      t.string :export_type, null: false
      t.string :format, null: false
      t.json :filters, default: {}
      t.boolean :include_custom_fields, default: false
      t.json :include_sections, default: {}
      t.references :requested_by, foreign_key: { to_table: :admin_users }, index: true
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.string :filename
      t.timestamps
    end

    create_table :custom_fields do |t|
      t.string :entity_type, null: false
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, default: "string"
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :custom_fields, %i[entity_type key], unique: true

    create_table :custom_field_values do |t|
      t.references :custom_field, null: false, foreign_key: true
      t.string :record_type, null: false
      t.integer :record_id, null: false
      t.text :value
      t.timestamps
    end
    add_index :custom_field_values, %i[record_type record_id custom_field_id], unique: true, name: "index_cfv_on_record_and_field"
  end
end
