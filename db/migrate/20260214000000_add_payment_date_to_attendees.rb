# frozen_string_literal: true

class AddPaymentDateToAttendees < ActiveRecord::Migration[7.0]
  def change
    add_column :attendees, :payment_date, :date
  end
end
