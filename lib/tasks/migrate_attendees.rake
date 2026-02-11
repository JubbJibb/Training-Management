namespace :data do
  desc "Move all existing attendees to potential customers"
  task migrate_attendees_to_potential: :environment do
    puts "Starting migration of attendees to potential customers..."
    
    # Update all attendees that are not already potential customers
    count = Attendee.where("status IS NULL OR status = '' OR status = 'attendee'").count
    updated = Attendee.where("status IS NULL OR status = '' OR status = 'attendee'").update_all(status: 'potential')
    
    puts "Updated #{updated} attendees to potential customers (out of #{count} total)"
    puts "Migration completed!"
  end
end
