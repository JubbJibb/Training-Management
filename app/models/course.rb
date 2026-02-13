# frozen_string_literal: true

class Course < ApplicationRecord
  validates :title, presence: true

  scope :recently_synced, -> { where.not(synced_at: nil).order(synced_at: :desc) }
  scope :by_title, -> { order(:title) }
end
