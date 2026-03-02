class AddVatExcludedToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :vat_excluded, :boolean, default: nil
  end
end
