# frozen_string_literal: true

# Syncs customer information for records with duplicate names.
# Groups customers by normalized name, then for each group merges non-blank
# values so every record gets complete information (company, phone, billing_*, tax_id, etc.).
# Email and name are not changed (each record keeps its own).
class CustomerSyncService
  SYNC_ATTRS = %w[company phone billing_address billing_name tax_id participant_type name_thai address].freeze

  def initialize(dry_run: false)
    @dry_run = dry_run
    @updated_ids = []
    @groups_processed = 0
  end

  def call
    groups = duplicate_name_groups
    groups.each do |normalized_name, customers|
      sync_group(customers)
    end
    { groups_processed: @groups_processed, customers_updated: @updated_ids.uniq.size, dry_run: @dry_run }
  end

  private

  def normalize_name(name)
    name.to_s.strip.gsub(/\s+/, " ")
  end

  def duplicate_name_groups
    Customer.all.group_by { |c| normalize_name(c.name) }.select { |_k, list| list.size > 1 }
  end

  def sync_group(customers)
    @groups_processed += 1
    merged = merged_attributes(customers)
    customers.each do |c|
      SYNC_ATTRS.each do |attr|
        next if merged[attr].blank?
        next if c[attr].to_s.present?

        if @dry_run
          @updated_ids << c.id
          break
        else
          c[attr] = merged[attr]
        end
      end
      if !@dry_run && c.changed?
        c.save!
        @updated_ids << c.id
      end
    end
  end

  def merged_attributes(customers)
    merged = {}
    SYNC_ATTRS.each do |attr|
      merged[attr] = customers.map { |c| c[attr].to_s.strip.presence }.compact.first
    end
    merged
  end
end
