# frozen_string_literal: true

class CreateAttendanceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_records do |t|
      t.references :training_class, null: false, foreign_key: true
      t.date :attendance_date, null: false
      t.string :learning_hour, null: false
      t.references :recorded_by, foreign_key: { to_table: :admin_users }, null: true
      t.timestamps
    end

    add_index :attendance_records, [:training_class_id, :attendance_date, :learning_hour],
              unique: true, name: "index_attendance_records_on_class_date_hour"
  end
end
