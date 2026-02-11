class AddParticipantFieldsToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :participant_type, :string, default: "Indi"
    add_column :attendees, :source_channel, :string
    add_column :attendees, :payment_status, :string, default: "Pending"
    add_column :attendees, :document_status, :string
    add_column :attendees, :attendance_status, :string, default: "No-show"
    add_column :attendees, :total_classes, :integer, default: 0
  end
end
