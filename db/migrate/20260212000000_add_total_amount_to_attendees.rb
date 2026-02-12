# frozen_string_literal: true

class AddTotalAmountToAttendees < ActiveRecord::Migration[8.0]
  def up
    add_column :attendees, :total_amount, :decimal, precision: 12, scale: 2
    change_column_default :attendees, :total_amount, from: nil, to: 0

    # Backfill from total_final_price (Amount shown in UI; includes VAT and promotions)
    reversible do |dir|
      dir.up do
        Attendee.reset_column_information
        Attendee.find_each do |a|
          a.update_column(:total_amount, a.total_final_price)
        end
      end
    end
  end

  def down
    remove_column :attendees, :total_amount
  end
end
