# frozen_string_literal: true

class AddSeatsToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :seats, :integer, default: 1, null: false
  end
end
