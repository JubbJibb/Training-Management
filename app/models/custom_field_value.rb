# frozen_string_literal: true

class CustomFieldValue < ApplicationRecord
  belongs_to :custom_field

  validates :record_type, :record_id, presence: true
  validates :custom_field_id, uniqueness: { scope: %i[record_type record_id] }
end
