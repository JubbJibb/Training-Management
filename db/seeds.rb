# Create default promotions
puts "Creating default promotions..."

Promotion.find_or_create_by!(name: "มา 4 จ่าย 3") do |p|
  p.discount_type = "buy_x_get_y"
  p.discount_value = 3
  p.description = "สมัคร 4 คน จ่ายแค่ 3 คน"
  p.active = true
  p.base_price = 0
end

Promotion.find_or_create_by!(name: "Earlybird") do |p|
  p.discount_type = "percentage"
  p.discount_value = 10
  p.description = "สมัครก่อนกำหนด ลด 10%"
  p.active = true
  p.base_price = 0
end

Promotion.find_or_create_by!(name: "Post and Share") do |p|
  p.discount_type = "percentage"
  p.discount_value = 5
  p.description = "แชร์โพสต์ ลด 5%"
  p.active = true
  p.base_price = 0
end

Promotion.find_or_create_by!(name: "Friend get friends") do |p|
  p.discount_type = "percentage"
  p.discount_value = 5
  p.description = "แนะนำเพื่อนมาสมัคร ลด 5%"
  p.active = true
  p.base_price = 0
end

puts "Default promotions created!"

# Create sample training classes
if TrainingClass.count == 0
  training_class1 = TrainingClass.create!(
    title: "Ruby on Rails Fundamentals",
    description: "Learn the basics of Ruby on Rails framework including MVC architecture, ActiveRecord, and routing.",
    date: 2.weeks.from_now.to_date,
    start_time: Time.parse("09:00"),
    end_time: Time.parse("17:00"),
    location: "Conference Room A",
    instructor: "John Doe",
    max_attendees: 20
  )

  training_class2 = TrainingClass.create!(
    title: "Advanced JavaScript",
    description: "Deep dive into modern JavaScript features including ES6+, async/await, and design patterns.",
    date: 3.weeks.from_now.to_date,
    start_time: Time.parse("10:00"),
    end_time: Time.parse("16:00"),
    location: "Conference Room B",
    instructor: "Jane Smith",
    max_attendees: 15
  )

  training_class3 = TrainingClass.create!(
    title: "Database Design Workshop",
    description: "Learn best practices for database design, normalization, and query optimization.",
    date: 1.week.ago.to_date,
    start_time: Time.parse("09:00"),
    end_time: Time.parse("17:00"),
    location: "Training Center",
    instructor: "Bob Johnson",
    max_attendees: 25
  )

  # Add sample attendees
  training_class1.attendees.create!([
    { name: "Alice Williams", email: "alice@example.com", phone: "555-0101", company: "Tech Corp" },
    { name: "Bob Brown", email: "bob@example.com", phone: "555-0102", company: "Dev Inc" },
    { name: "Charlie Davis", email: "charlie@example.com", phone: "555-0103", company: "StartupXYZ" }
  ])

  training_class2.attendees.create!([
    { name: "Diana Miller", email: "diana@example.com", phone: "555-0201", company: "Web Solutions" },
    { name: "Edward Wilson", email: "edward@example.com", phone: "555-0202", company: "Digital Agency" }
  ])

  training_class3.attendees.create!([
    { name: "Frank Moore", email: "frank@example.com", phone: "555-0301", company: "Data Systems" },
    { name: "Grace Lee", email: "grace@example.com", phone: "555-0302", company: "Cloud Services" },
    { name: "Henry Taylor", email: "henry@example.com", phone: "555-0303", company: "Enterprise Tech" },
    { name: "Ivy Chen", email: "ivy@example.com", phone: "555-0304", company: "Innovation Labs" }
  ])

  puts "Created #{TrainingClass.count} training classes with #{Attendee.count} total attendees"
end
