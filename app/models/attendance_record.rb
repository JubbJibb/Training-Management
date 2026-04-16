# frozen_string_literal: true

class AttendanceRecord < ApplicationRecord
  belongs_to :training_class
  belongs_to :recorded_by, class_name: "AdminUser", optional: true
  has_many :attendance_record_attendees, dependent: :destroy
  has_many :attendees, through: :attendance_record_attendees

  validates :attendance_date, presence: true
  validates :learning_hour, presence: true
  validates :learning_hour, inclusion: { in: ->(_) { AttendanceRecord.learning_hour_options.map { |_l, v| v } } }
  validates :attendance_date, uniqueness: { scope: [:training_class_id, :learning_hour] }

  class << self
    def learning_hour_options
      [
        ["รอบเช้า (09:00-12:00)", "09:00-12:00"],
        ["รอบบ่าย (13:00-16:00)", "13:00-16:00"],
        ["ทั้งวัน (09:00-16:00)", "09:00-16:00"],
        ["รอบ 1 (08:00-10:00)", "08:00-10:00"],
        ["รอบ 2 (10:30-12:30)", "10:30-12:30"],
        ["รอบ 3 (13:00-15:00)", "13:00-15:00"],
        ["รอบ 4 (15:30-17:30)", "15:30-17:30"]
      ].freeze
    end
  end

  def present_count
    attendance_record_attendees.where(present: true).count
  end

  def absent_count
    attendance_record_attendees.where(present: false).count
  end

  def unchecked_count
    total = attendance_record_attendees.count
    total_attendees = training_class.attendees.attendees.count
    [total_attendees - total, 0].max
  end

  def edited?
    return false unless updated_at.present? && created_at.present?
    (updated_at - created_at).abs > 2
  end

  def attendance_rate_percent
    total = training_class.attendees.attendees.count
    return nil if total.zero?
    ((present_count.to_f / total) * 100).round(0)
  end
end
