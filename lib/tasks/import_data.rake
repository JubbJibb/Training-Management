require 'csv'

namespace :data do
  desc "Import data from CSV files in db/Data"
  task import: :environment do
    puts "Starting data import..."
    
    # Import Training Classes and Attendees
    import_attendees
    
    # Import Payments
    import_payments
    
    # Import Quotations
    import_quotations_company
    import_quotations_indi
    
    puts "Data import completed!"
  end
  
  def import_attendees
    puts "\nImporting attendees..."
    file_path = Rails.root.join('db', 'Data', 'attendees_import.csv')
    
    return unless File.exist?(file_path)
    
    CSV.foreach(file_path, headers: true) do |row|
      next if row['name'].blank? || row['name'] == 'ค่าข้อมูล (อย่าลบ)' || row['name'].include?('Mail') || row['name'].include?('FaceBook') || row['name'].include?('Phone')
      
      class_key = row['class_key']&.strip
      class_title = row['class_title']&.strip
      
      next if class_title.blank?
      
      # Find or create training class
      training_class = TrainingClass.find_or_initialize_by(title: class_title)
      
      if training_class.new_record?
        # Extract date from class_title if possible (e.g., "Round 1", "Round 2")
        default_date = if class_title.include?('Round 1') || class_title.include?('R1')
          Date.parse('2026-03-12') rescue Date.today + 30.days
        elsif class_title.include?('Round 2') || class_title.include?('R2')
          Date.parse('2026-04-04') rescue Date.today + 60.days
        else
          Date.today + 30.days
        end
        
        training_class.assign_attributes(
          date: default_date,
          location: "TBD - To be determined",
          description: "Imported from CSV"
        )
        training_class.save!
      end
      
      # Skip if email is blank
      email = row['email']&.strip
      name = row['name']&.strip
      
      next if name.blank?
      
      # Create attendee - use email if available, otherwise use name+class as unique key
      if email.present?
        attendee = training_class.attendees.find_or_initialize_by(
          email: email,
          training_class_id: training_class.id
        )
      else
        # For attendees without email, use name as identifier
        attendee = training_class.attendees.find_or_initialize_by(
          name: name,
          training_class_id: training_class.id,
          email: "#{name.parameterize}@imported.local"
        )
      end
      
      # Clean phone number
      phone = row['phone']&.to_s&.strip&.gsub(/[^\d]/, '')
      phone = nil if phone.blank? || phone == '0'
      
      # Clean company
      company = row['company']&.strip
      company = nil if company.blank? || company == '-' || company == 'nan'
      
      attendee.assign_attributes(
        name: name,
        phone: phone,
        company: company,
        participant_type: normalize_participant_type(row['participant_type']&.strip),
        source_channel: normalize_source_channel(row['source_channel']&.strip),
        payment_status: normalize_payment_status(row['payment_status']&.strip),
        document_status: determine_document_status(row),
        invoice_no: row['invoice_no']&.strip.presence,
        notes: build_notes(row),
        total_classes: parse_seat(row['seat']),
        price: 0.0 # Will be updated from payments/quotations
      )
      
      if attendee.save
        print "."
      else
        puts "\nError importing #{name}: #{attendee.errors.full_messages.join(', ')}"
      end
    end
    
    puts "\nAttendees import completed!"
  end
  
  def import_payments
    puts "\nImporting payments..."
    file_path = Rails.root.join('db', 'Data', 'payments_import.csv')
    
    return unless File.exist?(file_path)
    
    CSV.foreach(file_path, headers: true) do |row|
      next if row['name'].blank? || row['paid_amount'].blank?
      
      email = row['email']&.strip
      name = row['name']&.strip
      phone = row['phone']&.to_s&.strip
      paid_amount = row['paid_amount']&.to_f || 0
      receipt_no = row['receipt_no']&.strip
      payment_date = parse_date(row['payment_date'])
      description = row['description']&.strip
      
      # Find attendee by email, name, or phone
      attendee = nil
      
      if email.present?
        attendee = Attendee.joins(:training_class)
                           .where("attendees.email = ?", email)
                           .where("training_classes.title LIKE ?", "%#{extract_class_from_description(description)}%")
                           .first
      end
      
      if attendee.nil? && name.present?
        attendee = Attendee.joins(:training_class)
                           .where("attendees.name = ?", name)
                           .where("training_classes.title LIKE ?", "%#{extract_class_from_description(description)}%")
                           .first
      end
      
      if attendee.nil? && phone.present?
        attendee = Attendee.joins(:training_class)
                           .where("attendees.phone = ?", phone)
                           .where("training_classes.title LIKE ?", "%#{extract_class_from_description(description)}%")
                           .first
      end
      
      if attendee
        attendee.update(
          payment_status: 'Paid',
          price: paid_amount,
          document_status: receipt_no.present? ? 'Receipt' : (attendee.document_status || 'Receipt')
        )
        print "."
      else
        puts "\nCould not find attendee: #{name} (#{email}) - #{description}"
      end
    end
    
    puts "\nPayments import completed!"
  end
  
  def import_quotations_company
    puts "\nImporting company quotations..."
    file_path = Rails.root.join('db', 'Data', 'quotations_company_import.csv')
    
    return unless File.exist?(file_path)
    
    CSV.foreach(file_path, headers: true) do |row|
      next if row['company_name'].blank? || row['qt_no'].blank?
      
      qt_no = row['qt_no']&.strip
      company_name = row['company_name']&.strip
      class_title = row['class_title']&.strip
      amount = row['amount_inc_vat']&.to_f || 0
      
      # Find training class
      training_class = TrainingClass.where("title LIKE ?", "%#{class_title}%").first
      next unless training_class
      
      # Extract number of participants from description
      description = row['description']&.strip || ''
      participant_count = extract_participant_count(description)
      
      # Find attendees from this company
      company_attendees = training_class.attendees
                                       .where(company: company_name)
                                       .where(participant_type: 'Corp')
      
      if company_attendees.any?
        # Use participant count from description if available, otherwise use actual count
        count_to_use = participant_count > 0 ? participant_count : company_attendees.count
        price_per_attendee = amount / count_to_use
        
        company_attendees.each do |attendee|
          attendee.update(
            document_status: 'QT',
            price: price_per_attendee
          )
        end
        print "."
      else
        puts "\nCould not find attendees for company: #{company_name} in #{class_title}"
      end
    end
    
    puts "\nCompany quotations import completed!"
  end
  
  def import_quotations_indi
    puts "\nImporting individual quotations..."
    file_path = Rails.root.join('db', 'Data', 'quotations_indi_import.csv')
    
    return unless File.exist?(file_path)
    
    CSV.foreach(file_path, headers: true) do |row|
      next if row['name'].blank? || row['qt_no'].blank?
      
      name = row['name']&.strip
      email = row['email']&.strip
      class_title = row['class_title']&.strip
      amount = row['amount_inc_vat']&.to_f || 0
      
      # Find training class
      training_class = TrainingClass.where("title LIKE ?", "%#{class_title}%").first
      next unless training_class
      
      # Find attendee
      attendee = training_class.attendees.find_by(email: email) || 
                 training_class.attendees.find_by(name: name)
      
      if attendee
        attendee.update(
          document_status: 'QT',
          price: amount
        )
        print "."
      end
    end
    
    puts "\nIndividual quotations import completed!"
  end
  
  def normalize_payment_status(status)
    return 'Pending' if status.blank? || status.downcase == 'nan'
    status == 'Paid' ? 'Paid' : 'Pending'
  end
  
  def normalize_participant_type(type)
    return 'Indi' if type.blank? || type.downcase == 'nan'
    type == 'Corp' ? 'Corp' : 'Indi'
  end
  
  def normalize_source_channel(channel)
    return nil if channel.blank? || channel.downcase == 'nan'
    channel
  end
  
  def determine_document_status(row)
    if row['receipt_no'].present?
      'Receipt'
    elsif row['invoice_no'].present?
      'INV'
    elsif row['qt_no'].present?
      'QT'
    else
      nil
    end
  end
  
  def build_notes(row)
    notes_parts = []
    notes_parts << row['notes'] if row['notes'].present?
    notes_parts << "Confirm: #{row['confirm_status']}" if row['confirm_status'].present?
    notes_parts << "Reply: #{row['reply_status']}" if row['reply_status'].present?
    notes_parts.join(' | ').presence
  end
  
  def parse_seat(seat_value)
    return 0 if seat_value.blank?
    seat_value.to_f.to_i
  end
  
  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string) rescue nil
  end
  
  def extract_class_from_description(description)
    return '' if description.blank?
    
    # Try to extract class name from description
    if description.include?('Fundamental') || description.include?('Software Architect')
      'Fundamentals of Software Architecture'
    elsif description.include?('Refactoring') || description.include?('Functional')
      'Refactoring to Functional'
    elsif description.include?('Agile') || description.include?('Scrum')
      'Introduction to Agile and Scrum'
    elsif description.include?('Event Driven')
      'Event Driven Architecture'
    else
      description.split(' ').first || ''
    end
  end
  
  def extract_participant_count(description)
    return 0 if description.blank?
    
    # Look for patterns like "for 5 Participants", "for 4 Participant", "Max 24 Participants"
    if match = description.match(/for\s+(\d+)\s+participant/i)
      match[1].to_i
    elsif match = description.match(/max\s+(\d+)\s+participant/i)
      match[1].to_i
    elsif match = description.match(/(\d+)\s+participant/i)
      match[1].to_i
    else
      0
    end
  end
end
