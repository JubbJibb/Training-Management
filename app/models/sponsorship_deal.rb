# frozen_string_literal: true

class SponsorshipDeal < ApplicationRecord
  STATUSES = %w[planned committed paid].freeze

  belongs_to :event, class_name: "Budget::Event", foreign_key: :event_id
  has_many :budget_expenses, class_name: "Budget::Expense", foreign_key: :sponsorship_deal_id, dependent: :nullify

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
