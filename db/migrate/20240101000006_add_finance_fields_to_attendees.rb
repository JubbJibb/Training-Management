class AddFinanceFieldsToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :invoice_no, :string
    add_column :attendees, :due_date, :date
  end
end
