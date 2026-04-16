# frozen_string_literal: true

class AttendanceRecordAttendee < ApplicationRecord
  belongs_to :attendance_record
  belongs_to :attendee

  validates :attendee_id, uniqueness: { scope: :attendance_record_id }
end
