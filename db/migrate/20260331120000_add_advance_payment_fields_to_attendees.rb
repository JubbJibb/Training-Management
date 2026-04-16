class AddAdvancePaymentFieldsToAttendees < ActiveRecord::Migration[7.1]
  def change
    add_column :attendees, :advance_paid_amount, :decimal, precision: 12, scale: 2
    add_column :attendees, :advance_paid_note, :text
  end
end

