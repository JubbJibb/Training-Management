# frozen_string_literal: true

class ExportJob < ApplicationRecord
  belongs_to :requested_by, class_name: "AdminUser", optional: true
  has_one_attached :file

  EXPORT_TYPES = %w[
    financial_report class_report customer_summary
    financial_data class_attendees customer_master customer_for_accounting
    custom_export
  ].freeze
  FORMATS = %w[pdf xlsx].freeze
  STATES = %w[queued running succeeded failed].freeze

  validates :export_type, presence: true, inclusion: { in: EXPORT_TYPES }
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :state, presence: true, inclusion: { in: STATES }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_download, -> { where(state: "succeeded") }

  def queued? = state == "queued"
  def running? = state == "running"
  def succeeded? = state == "succeeded"
  def failed? = state == "failed"

  def filters_hash
    filters.is_a?(Hash) ? filters : {}
  end

  def include_sections_hash
    include_sections.is_a?(Hash) ? include_sections : {}
  end

  def mark_running!
    update!(state: "running", started_at: Time.current)
  end

  def mark_succeeded!(filename:, io:)
    file.attach(io: io, filename: filename)
    update!(state: "succeeded", finished_at: Time.current, filename: filename, error_message: nil)
  end

  def mark_failed!(message)
    update!(state: "failed", finished_at: Time.current, error_message: message)
  end
end
