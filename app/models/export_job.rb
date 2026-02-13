# frozen_string_literal: true

class ExportJob < ApplicationRecord
  belongs_to :requested_by, class_name: "AdminUser", optional: true
  has_one_attached :file

  EXPORT_TYPES = %w[
    financial_report class_report customer_summary
    financial_data class_attendees customer_master customer_for_accounting
    overall_revenue_summary class_financial_report
    attendee_master_editable pending_receipt attendee_complete
    custom_export
  ].freeze
  FORMATS = %w[pdf xlsx].freeze
  STATES = %w[queued running succeeded failed].freeze

  # Category for UI grouping: financial_reports | attendee_documents
  EXPORT_TYPE_CATEGORY = {
    "financial_report" => "financial_reports",
    "class_report" => "financial_reports",
    "customer_summary" => "financial_reports",
    "financial_data" => "financial_reports",
    "overall_revenue_summary" => "financial_reports",
    "class_financial_report" => "financial_reports",
    "class_attendees" => "attendee_documents",
    "customer_master" => "attendee_documents",
    "customer_for_accounting" => "attendee_documents",
    "attendee_master_editable" => "attendee_documents",
    "pending_receipt" => "attendee_documents",
    "attendee_complete" => "attendee_documents",
    "custom_export" => "attendee_documents"
  }.freeze

  EXPORT_TYPE_LABEL = {
    "financial_report" => "Financial Report (PDF)",
    "class_report" => "Class Report (PDF)",
    "customer_summary" => "Customer Summary (PDF)",
    "financial_data" => "Financial Data (Excel)",
    "overall_revenue_summary" => "Overall Revenue Summary",
    "class_financial_report" => "Class-Specific Financial Report",
    "class_attendees" => "Class Attendees (Excel)",
    "customer_master" => "Customer Master (Editable)",
    "customer_for_accounting" => "Customer for Accounting",
    "attendee_master_editable" => "Attendee Master (Editable & Re-uploadable)",
    "pending_receipt" => "Pending Receipt Generation",
    "attendee_complete" => "Complete Attendee Export",
    "custom_export" => "Custom Export"
  }.freeze

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

  def category
    EXPORT_TYPE_CATEGORY[export_type] || "attendee_documents"
  end

  def label
    EXPORT_TYPE_LABEL[export_type] || export_type.humanize
  end

  def filters_summary
    h = filters_hash.symbolize_keys
    parts = []
    parts << "Period: #{h[:period]}" if h[:period].present?
    parts << "From #{h[:start_date]}" if h[:start_date].present?
    parts << "To #{h[:end_date]}" if h[:end_date].present?
    parts << "Classes: #{Array(h[:class_ids]).size} selected" if Array(h[:class_ids]).any?
    parts << "Payment: #{h[:payment_status]}" if h[:payment_status].present?
    parts << "Breakdown: #{h[:breakdown]}" if h[:breakdown].present?
    parts << "Purpose: #{h[:purpose]}" if h[:purpose].present?
    parts.any? ? parts.join(" · ") : "Default filters"
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
