class AddStatusToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :status, :string, default: "attendee"
  end
end
