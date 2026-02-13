# frozen_string_literal: true

# Merges a source Customer into a primary Customer (keeps primary, removes source).
# - Reassigns all attendees from source to primary
# - Optionally copies blank attributes from source to primary
# - Destroys the source customer
class CustomerMergeService
  MERGE_ATTRS = %w[company phone billing_address billing_name tax_id name_thai address].freeze

  def initialize(primary:, source:)
    @primary = primary
    @source = source
    @attendees_reassigned = 0
    @attrs_updated = []
  end

  def call
    return error("primary และ source ต้องเป็นคนละรายการ") if @primary.id == @source.id
    return error("ไม่พบ Customer หลัก") unless @primary.persisted?
    return error("ไม่พบ Customer ที่จะ merge") unless @source.persisted?

    ActiveRecord::Base.transaction do
      reassign_attendees
      copy_blank_attributes_from_source
      @source.destroy!
    end

    { success: true, attendees_reassigned: @attendees_reassigned, attrs_updated: @attrs_updated }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: e.message }
  end

  private

  def error(msg)
    { success: false, error: msg }
  end

  def reassign_attendees
    count = @source.attendees.update_all(customer_id: @primary.id)
    @attendees_reassigned = count
  end

  def copy_blank_attributes_from_source
    MERGE_ATTRS.each do |attr|
      next unless @primary.respond_to?(attr) && @source.respond_to?(attr)
      next if @primary[attr].to_s.present?
      next if @source[attr].to_s.blank?

      @primary[attr] = @source[attr]
      @attrs_updated << attr
    end
    @primary.save! if @attrs_updated.any?
  end
end
