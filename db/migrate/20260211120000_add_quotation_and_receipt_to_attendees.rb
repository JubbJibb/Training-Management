# frozen_string_literal: true

class AddQuotationAndReceiptToAttendees < ActiveRecord::Migration[8.0]
  def change
    add_column :attendees, :quotation_no, :string
    add_column :attendees, :receipt_no, :string
  end
end
