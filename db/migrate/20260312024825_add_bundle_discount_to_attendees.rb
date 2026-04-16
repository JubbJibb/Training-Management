class AddBundleDiscountToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :bundle_discount_percent, :decimal, precision: 5, scale: 2
    add_column :attendees, :bundle_discount_fixed, :decimal, precision: 10, scale: 2
  end
end
