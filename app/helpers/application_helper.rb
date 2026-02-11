module ApplicationHelper
  def number_with_delimiter(number, options = {})
    delimiter = options[:delimiter] || ","
    separator = options[:separator] || "."
    
    # ปัดเป็นทศนิยม 2 ตำแหน่ง
    rounded_number = number.to_f.round(2)
    
    parts = rounded_number.to_s.split(".")
    parts[0] = parts[0].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    
    # ตรวจสอบว่ามีทศนิยมหรือไม่ ถ้าไม่มีให้เพิ่ม .00
    if parts.length == 1
      parts << "00"
    elsif parts[1].length == 1
      parts[1] = parts[1] + "0"
    end
    
    parts.join(separator)
  end
  
  def mailto_class_info_link(attendee)
    training_class = attendee.training_class
    subject = "Training Class Information: #{training_class.title}"
    
    body = "Dear #{attendee.name},\n\n"
    body += "Thank you for registering for our training class. Here are the details:\n\n"
    body += "#{training_class.title}\n\n"
    body += "Date: #{training_class.date.strftime("%B %d, %Y")}"
    if training_class.end_date && training_class.end_date != training_class.date
      body += " - #{training_class.end_date.strftime("%B %d, %Y")}"
    end
    body += "\n"
    
    if training_class.start_time && training_class.end_time
      body += "Time: #{training_class.start_time.strftime("%I:%M %p")} - #{training_class.end_time.strftime("%I:%M %p")}\n"
    end
    
    body += "Duration: #{training_class.duration}\n"
    body += "Location: #{training_class.location}\n"
    
    if training_class.instructor
      body += "Instructor: #{training_class.instructor}\n"
    end
    
    if training_class.description.present?
      body += "\nDescription:\n#{training_class.description}\n"
    end
    
    body += "\nWe look forward to seeing you at the training!\n\n"
    body += "Best regards,\nTraining Management Team"
    
    mailto_link(attendee.email, subject, body)
  end
  
  def mailto_reminder_link(attendee)
    training_class = attendee.training_class
    subject = "Reminder: #{training_class.title} - #{training_class.date.strftime('%B %d, %Y')}"
    
    body = "Dear #{attendee.name},\n\n"
    body += "This is a friendly reminder that you are registered for:\n\n"
    body += "#{training_class.title}\n\n"
    body += "Date: #{training_class.date.strftime("%B %d, %Y")}"
    if training_class.end_date && training_class.end_date != training_class.date
      body += " - #{training_class.end_date.strftime("%B %d, %Y")}"
    end
    body += "\n"
    
    if training_class.start_time && training_class.end_time
      body += "Time: #{training_class.start_time.strftime("%I:%M %p")} - #{training_class.end_time.strftime("%I:%M %p")}\n"
    end
    
    body += "Location: #{training_class.location}\n\n"
    body += "We look forward to seeing you there!\n\n"
    body += "Best regards,\nTraining Management Team"
    
    mailto_link(attendee.email, subject, body)
  end
  
  def mailto_link(email, subject, body)
    # URL encode the parameters properly
    encoded_subject = URI.encode_www_form_component(subject)
    encoded_body = URI.encode_www_form_component(body)
    
    "mailto:#{email}?subject=#{encoded_subject}&body=#{encoded_body}"
  end
  
  def mailto_all_attendees_link(training_class)
    emails = training_class.attendees.attendees.pluck(:email).compact
    return "#" if emails.empty?
    
    # Use BCC for multiple recipients
    bcc = emails.join(";")
    subject = "Message regarding #{training_class.title}"
    body = "Dear Attendees,\n\n"
    body += "This message is regarding: #{training_class.title}\n"
    body += "Date: #{training_class.date.strftime("%B %d, %Y")}\n\n"
    body += "[Your message here]\n\n"
    body += "Best regards,\nTraining Management Team"
    
    # URL encode the parameters
    encoded_bcc = URI.encode_www_form_component(bcc)
    encoded_subject = URI.encode_www_form_component(subject)
    encoded_body = URI.encode_www_form_component(body)
    
    "mailto:?bcc=#{encoded_bcc}&subject=#{encoded_subject}&body=#{encoded_body}"
  end
end
