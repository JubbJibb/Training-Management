# frozen_string_literal: true

class AddTaxInfoToAttendees < ActiveRecord::Migration[8.0]
  def change
    add_column :attendees, :name_thai, :string
    add_column :attendees, :tax_id, :string
    add_column :attendees, :address, :text
  end
end
