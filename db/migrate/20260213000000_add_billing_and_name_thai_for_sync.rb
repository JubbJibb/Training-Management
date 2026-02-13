# frozen_string_literal: true

class AddBillingAndNameThaiForSync < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :name_thai, :string
    add_column :customers, :address, :text

    add_column :attendees, :billing_name, :string
    add_column :attendees, :billing_address, :text
  end
end
