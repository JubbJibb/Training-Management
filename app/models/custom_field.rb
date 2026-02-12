# frozen_string_literal: true

class CustomField < ApplicationRecord
  has_many :custom_field_values, dependent: :destroy

  ENTITY_TYPES = %w[customer class invoice].freeze
  FIELD_TYPES = %w[string number date boolean].freeze

  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }
  validates :key, presence: true, uniqueness: { scope: :entity_type }
  validates :label, presence: true
  validates :field_type, inclusion: { in: FIELD_TYPES }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :for_entity, ->(entity) { where(entity_type: entity).active }
end
