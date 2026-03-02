# frozen_string_literal: true

class AddFinancialsIndexesToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_index :attendees, [:due_date, :payment_status], name: "index_attendees_on_due_date_and_payment_status"
  end
end
