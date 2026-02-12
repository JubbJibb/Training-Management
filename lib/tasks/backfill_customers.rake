namespace :customers do
  desc "Backfill Customer records from existing Attendees and link attendees.customer_id"
  task backfill: :environment do
    puts "Backfilling customers from attendees..."

    created = 0
    linked = 0
    skipped = 0

    Attendee.find_each do |attendee|
      email = attendee.email.to_s.strip.downcase
      if email.blank?
        skipped += 1
        next
      end

      customer = Customer.find_or_initialize_by(email: email)
      created += 1 if customer.new_record?

      # Only fill blanks; never overwrite existing master data
      customer.name = attendee.name if customer.name.blank?
      customer.phone = attendee.phone if customer.phone.blank?
      customer.participant_type = attendee.participant_type if customer.participant_type.blank?
      customer.company = attendee.company if customer.company.blank?
      if attendee.participant_type == "Corp" && customer.billing_name.blank? && attendee.company.present?
        customer.billing_name = attendee.company
      end

      customer.save! if customer.new_record? || customer.changed?

      if attendee.customer_id != customer.id
        attendee.update_columns(customer_id: customer.id, updated_at: Time.current)
        linked += 1
      end
    end

    puts "Done. customers_created=#{created} attendees_linked=#{linked} attendees_skipped_no_email=#{skipped}"
  end

  desc "Sync customer information for duplicate names (fill blank fields from others with same name)"
  task :sync_duplicates, [:dry_run] => :environment do |_t, args|
    dry_run = args[:dry_run] != "false"
    puts "Syncing customers with duplicate names (dry_run=#{dry_run})..."

    result = CustomerSyncService.new(dry_run: dry_run).call

    puts "Done. groups_processed=#{result[:groups_processed]} customers_updated=#{result[:customers_updated]} dry_run=#{result[:dry_run]}"
  end
end

