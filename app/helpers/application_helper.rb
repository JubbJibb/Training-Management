module ApplicationHelper
  include Odt::UiHelper

  # Returns "nav-link active" or "nav-link" for navbar (legacy flat nav).
  def nav_class(tab_name)
    base = "nav-link"
    active = nav_active?(tab_name.to_s)
    active ? "#{base} active" : base
  end

  # Returns "active" or "" for dropdown parent (executive IA).
  # section: insights | operations | clients | financials | strategy | settings
  def nav_active?(section)
    path = request.path
    case section.to_s
    when "insights" then path.start_with?("/insights")
    when "operations" then path.start_with?("/admin/training_classes") || path.start_with?("/admin/courses") || path.start_with?("/instructors") || path.start_with?("/training_classes") || path.start_with?("/courses")
    when "clients" then path.start_with?("/admin/customers") || path.start_with?("/customers") || path.start_with?("/clients") || (path.start_with?("/admin/customers") && params[:segment].present?)
    when "financials" then path.start_with?("/finance") || path.start_with?("/finance_dashboard") || controller.controller_path == "admin/finance" || controller.controller_path == "admin/exports" || controller.controller_path == "admin/expenses" || controller.controller_path == "admin/compliance" || controller.controller_path == "finance_dashboards"
    when "strategy" then controller.controller_path == "admin/settings" || path.start_with?("/promotions")
    when "settings" then controller.controller_path == "admin/settings"
    when "admin" then controller.controller_path == "admin/dashboard"
    when "cfo" then controller.controller_path == "finance_dashboards"
    when "training_classes" then %w[admin/training_classes admin/attendees admin/class_expenses].include?(controller.controller_path)
    when "customers" then controller.controller_path == "admin/customers"
    when "courses" then controller.controller_path == "admin/courses"
    when "exports" then controller.controller_path == "admin/exports"
    else false
    end ? "active" : ""
  end

  # Format number as Thai Baht (e.g. ฿1,234.56)
  def number_to_thb(number, decimals: 2)
    n = number.to_f.round(decimals)
    "฿#{number_with_delimiter(n, delimiter: ',')}"
  end

  # Format number as percent (e.g. 12.5%)
  def number_to_percent(number, decimals: 1)
    "#{number.to_f.round(decimals)}%"
  end

  def inline_error_for(record, attribute)
    return "" unless record.is_a?(ActiveModel::Errors) || (record.respond_to?(:errors) && record.errors[attribute].any?)
    messages = record.respond_to?(:errors) ? record.errors.full_messages_for(attribute) : []
    return "" if messages.empty?
    content_tag(:span, messages.first, class: "customer-edit-field-error", role: "alert")
  end

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
