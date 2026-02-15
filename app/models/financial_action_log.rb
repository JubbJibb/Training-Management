# frozen_string_literal: true

class FinancialActionLog < ApplicationRecord
  belongs_to :actor, class_name: "AdminUser", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action_type, presence: true
  validates :subject_type, presence: true
  validates :subject_id, presence: true
  validates :status, inclusion: { in: %w[queued sent failed] }

  serialize :metadata, coder: JSON

  scope :send_payment_summary, -> { where(action_type: "send_payment_summary") }
  scope :recent, -> { order(created_at: :desc) }
end
