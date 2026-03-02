# frozen_string_literal: true

class AddSlipVerifiedAtToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :slip_verified_at, :datetime
  end
end
