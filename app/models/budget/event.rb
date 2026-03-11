# frozen_string_literal: true

module Budget
  class Event < ApplicationRecord
    self.table_name = "budget_events"

    has_many :sponsorship_deals, dependent: :destroy

    validates :name, presence: true

    scope :by_start_date, -> { order(start_date: :desc) }
  end
end
