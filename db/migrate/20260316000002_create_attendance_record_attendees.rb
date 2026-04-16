# frozen_string_literal: true

class CreateAttendanceRecordAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_record_attendees do |t|
      t.references :attendance_record, null: false, foreign_key: true
      t.references :attendee, null: false, foreign_key: true
      t.boolean :present, default: false, null: false
      t.timestamps
    end

    add_index :attendance_record_attendees, [:attendance_record_id, :attendee_id],
              unique: true, name: "index_ara_on_record_and_attendee"
  end
end
