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

Promotion.find_or_create_by!(name: "ส่วนลดศิษย์เก่า") do |p|
  p.discount_type = "percentage"
  p.discount_value = 10
  p.description = "ส่วนลดสำหรับศิษย์เก่าที่เคยเรียนกับเรา"
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

# Budget: default categories
puts "Creating budget categories..."
[
  { name: "Trainer", code: "TRAIN", sort_order: 1, cost_type: "variable" },
  { name: "Staff (Manday)", code: "STAFF", sort_order: 2, cost_type: "variable" },
  { name: "Marketing Campaign", code: "MKT", sort_order: 3, cost_type: "variable" },
  { name: "Equipment", code: "EQUIP", sort_order: 4, cost_type: "fixed" },
  { name: "Event Sponsorship", code: "SPONSOR", sort_order: 5, cost_type: "variable" }
].each do |attrs|
  Budget::Category.find_or_create_by!(code: attrs[:code]) do |c|
    c.name = attrs[:name]
    c.sort_order = attrs[:sort_order]
    c.cost_type = attrs[:cost_type]
  end
end
puts "Budget categories created!"

# Sample budget year (current year) if none
if Budget::Year.where(year: Date.current.year).none?
  by = Budget::Year.create!(year: Date.current.year, status: "active", total_budget: 0, owner_name: "System")
  Budget::Category.ordered.each do |cat|
    Budget::Allocation.find_or_create_by!(budget_year_id: by.id, budget_category_id: cat.id) do |a|
      a.allocated_amount = 0
    end
  end
  puts "Created budget year #{by.year} with allocations."
end

# ODT Staff (Budget Staff profiles)
puts "Creating ODT staff profiles..."
odt_staff = [
  { name_eng: "Raktiboon", lastname_eng: "Prasertsomphob", nickname_eng: "Ploy", email: "Raktiboon@odds.team", phone: "0875088959", team: "Internal/External" },
  { name_eng: "Prakit", lastname_eng: "Aroonkitcharoen", nickname_eng: "Tor", email: "tortaywe@gmail.com", phone: "0625373842", team: "External engagement" },
  { name_eng: "Nattapat", lastname_eng: "Pinrat", nickname_eng: "Frost", email: "frosty2544@gmail.com", phone: "0957034020", team: "External engagement" },
  { name_eng: "Thitirat", lastname_eng: "Touythong", nickname_eng: "Mo", email: "tthitirath@gmail.com", phone: "0955211953", team: "External engagement" },
  { name_eng: "Teeratorn", lastname_eng: "Raksamuang", nickname_eng: "Un", email: "teeratorn.r@odds.team", phone: "0637705685", team: "Internal Engagement" },
  { name_eng: "Suphachai", lastname_eng: "Yarasai", nickname_eng: "Ohm", email: "ohmarsy@odds.team", phone: "0987493528", team: "Internal Engagement" },
  { name_eng: "Naphas", lastname_eng: "Seenakasa", nickname_eng: "Nampu", email: "napat.sinakasa@gmail.com", phone: "0951803484", team: "External engagement" },
  { name_eng: "Nisit", lastname_eng: "Nunuan", nickname_eng: "Nack", email: "nisit@gmail.com", phone: "0628869733", team: "Internal engagement" },
  { name_eng: "Chanon", lastname_eng: "Wiriyathanachit", nickname_eng: "Non", email: "non@odds.team", phone: "0921454487", team: "Internal engagement" }
]
odt_staff.each do |row|
  name = "#{row[:name_eng]} #{row[:lastname_eng]}".strip
  p = Budget::StaffProfile.find_or_initialize_by(name: name)
  p.nickname = row[:nickname_eng]
  p.email = row[:email]
  p.phone = row[:phone]
  p.department = row[:team]
  p.status = "active"
  p.internal_day_rate = 0 if p.new_record?
  p.save!
end
puts "ODT staff profiles: #{Budget::StaffProfile.count} records."
