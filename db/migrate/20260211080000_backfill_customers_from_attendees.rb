class BackfillCustomersFromAttendees < ActiveRecord::Migration[8.1]
  # Backfill customer master data from existing attendees and link attendee.customer_id.
  # Idempotent: safe to run multiple times.
  #
  # Why: otherwise Customers pages may look empty until running a manual rake task.
  def up
    return unless table_exists?(:attendees) && table_exists?(:customers)
    return unless column_exists?(:attendees, :customer_id)

    say_with_time "Backfilling customers from attendees and linking attendee.customer_id" do
      migration_customer = Class.new(ActiveRecord::Base) do
        self.table_name = "customers"
      end

      migration_attendee = Class.new(ActiveRecord::Base) do
        self.table_name = "attendees"
      end

      migration_attendee.reset_column_information
      migration_customer.reset_column_information

      migration_attendee.where(customer_id: nil).where.not(email: [nil, ""]).find_in_batches(batch_size: 500) do |batch|
        batch.each do |a|
          email = a.email.to_s.strip.downcase
          next if email.blank?

          c = migration_customer.where("lower(email) = ?", email).first
          if c.nil?
            c = migration_customer.new(email: email, name: a.name.presence || email)
          end

          # Only fill blanks; never overwrite existing master data
          c.name = a.name if c.name.blank? && a.name.present?
          c.phone = a.phone if c.respond_to?(:phone) && c.phone.blank? && a.phone.present?
          c.participant_type = a.participant_type if c.respond_to?(:participant_type) && c.participant_type.blank? && a.participant_type.present?
          c.company = a.company if c.respond_to?(:company) && c.company.blank? && a.company.present?

          if a.respond_to?(:participant_type) && a.participant_type == "Corp" &&
             c.respond_to?(:billing_name) && c.billing_name.blank? &&
             a.respond_to?(:company) && a.company.present?
            c.billing_name = a.company
          end

          c.save!(validate: false) if c.new_record? || c.changed?
          a.update_columns(customer_id: c.id, updated_at: Time.current) if a.customer_id != c.id
        end
      end
    end
  end

  def down
    # no-op (data migration)
  end
end

