# frozen_string_literal: true

class MigratePaymentSlipToPaymentSlips < ActiveRecord::Migration[8.0]
  def up
    # Active Storage: rename attachment so existing single slip becomes first of many
    execute <<-SQL.squish
      UPDATE active_storage_attachments
      SET name = 'payment_slips'
      WHERE record_type = 'Attendee' AND name = 'payment_slip'
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE active_storage_attachments
      SET name = 'payment_slip'
      WHERE record_type = 'Attendee' AND name = 'payment_slips'
    SQL
  end
end
