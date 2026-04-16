module ApplicationHelper
  include Odt::UiHelper

  # Flowbite icon via Iconify CDN. Use in nav and elsewhere.
  # Icon names: https://icon-sets.iconify.design/flowbite/ (e.g. "calendar-outline", "chart-bar-outline").
  # Options: class (default "nav-link-icon" when in nav), aria_hidden (default true), data: {}
  def flowbite_icon(icon_name, **options)
    css_class = options.delete(:class) || "nav-link-icon"
    aria_hidden = options.fetch(:aria_hidden, true)
    data_attrs = options.delete(:data) || {}
    attrs = {
      class: "iconify #{css_class}".strip,
      "data-icon": "flowbite:#{icon_name}",
      "aria-hidden": aria_hidden
    }.merge(options).merge(data: data_attrs)
    tag.span(**attrs)
  end

  # Business Insights: Flowbite-style info tooltip. Returns { title:, body: } for known keys (KPIs, table headers, cohort).
  # Use with: render "shared/bi_info_tooltip", **bi_tooltip_content(:revenue)
  def bi_tooltip_content(key)
    h = {
      revenue: ["รายได้ (หลังหักส่วนลด)", "รวมยอดชำระเงินสำเร็จในช่วงที่เลือก (ไม่รวมรายการยกเลิก/คืนเงิน)"],
      paid_orders: ["การชำระเงินสำเร็จ", "จำนวนรายการชำระเงินที่สถานะ \"สำเร็จ\" ในช่วงที่เลือก"],
      avg_price_per_head: ["ราคาเฉลี่ยต่อคน", "รายได้ ÷ จำนวนการชำระเงิน (หรือจำนวนผู้เรียนที่ชำระจริง หากระบบนับแบบที่นั่ง)"],
      cvr: ["อัตราปิดการขาย (สมัคร→จ่าย)", "การชำระเงินสำเร็จ ÷ จำนวนผู้สมัคร (Leads) ในช่วงที่เลือก"],
      repeat_rate: ["อัตราเรียนซ้ำ", "สัดส่วนลูกค้าที่เคยซื้อ/เรียนมาก่อน แล้วกลับมาชำระเงินอีกครั้ง"],
      gross_margin: ["กำไรขั้นต้น", "รายได้ − ต้นทุนคลาส (ถ้าไม่มีข้อมูลต้นทุน จะแสดง N/A)"],
      returning_revenue: ["รายได้จากลูกค้าเดิม", "รายได้จากลูกค้าที่เคยซื้อ/เรียนมาก่อน ÷ รายได้ทั้งหมด"],
      leads: ["Leads (ผู้สมัคร)", "จำนวนผู้ที่สมัคร/ลงทะเบียนในช่วงที่เลือก (นับเป็นคน ไม่ใช่จำนวนครั้ง)"],
      cohort: ["Cohort คืออะไร", "แบ่งกลุ่มลูกค้าตาม \"เดือนที่ซื้อครั้งแรก\" แล้วดู % ที่กลับมาซื้อในเดือนถัดๆ ไป"],
      cvr_header: ["CVR (ปิดการขาย)", "ชำระเงิน ÷ Leads ของรายการนั้น (คอร์ส/ช่องทาง)"],
      avg_head_header: ["เฉลี่ย/คน", "ราคาเฉลี่ยต่อคน (รายได้ ÷ จำนวนชำระ)"],
      revenue_header: ["รายได้", "รวมยอดชำระเงินสำเร็จในช่วงที่เลือก (หลังหักส่วนลด)"]
    }
    k = key.to_s.to_sym
    title, body = h[k]
    return {} if title.blank?
    { title: title, body: body.to_s }
  end

  # Renders the info tooltip partial with title/body; optional placement. Use when you have custom copy.
  def bi_info_tooltip(title:, body:, placement: "top")
    render "shared/bi_info_tooltip", title: title, body: body, placement: placement
  end

  # Returns "nav-link active" or "nav-link" for navbar (legacy flat nav).
  def nav_class(tab_name)
    base = "nav-link"
    active = nav_active?(tab_name.to_s)
    active ? "#{base} active" : base
  end

  # Pending count for Action Center badge in Insights dropdown. Replace with real query if needed.
  def insights_action_center_pending_count
    # TODO: e.g. Insights::ActionCenter.new.call then sum critical + warning + follow_up counts
    0
  end

  # Financials nav: indicators for dropdown (alert "!", dot, count). Returns hash.
  # Keys: overview_alert, ar_alert, ar_count, payments_alert, payments_count, expenses_alert, compliance_alert, export_count
  def financials_nav_indicators
    return @financials_nav_indicators if defined?(@financials_nav_indicators) && @financials_nav_indicators.present?
    @financials_nav_indicators = {
      overview_alert: false,
      ar_alert: false,
      ar_count: nil,
      payments_alert: false,
      payments_count: nil,
      expenses_alert: false,
      compliance_alert: false,
      export_count: nil
    }
    return @financials_nav_indicators unless defined?(Attendee)
    overdue = Attendee.attendees.where(payment_status: "Pending").where("attendees.due_date IS NOT NULL AND attendees.due_date < ?", Date.current).count
    @financials_nav_indicators[:ar_alert] = overdue.positive?
    @financials_nav_indicators[:ar_count] = overdue if overdue.positive?
    paid_no_receipt = Attendee.attendees.where(payment_status: "Paid").where("document_status IS NULL OR document_status != ?", "Receipt").count
    @financials_nav_indicators[:payments_alert] = paid_no_receipt.positive?
    @financials_nav_indicators[:payments_count] = paid_no_receipt if paid_no_receipt.positive?
    @financials_nav_indicators[:overview_alert] = @financials_nav_indicators[:ar_alert] || @financials_nav_indicators[:payments_alert]
    @financials_nav_indicators
  rescue
    @financials_nav_indicators ||= {}
  end

  # Returns "active" or "" for dropdown parent (executive IA).
  # section: insights | operations | clients | financials | strategy | settings
  def nav_active?(section)
    path = request.path
    case section.to_s
    when "insights" then path.start_with?("/insights")
    when "operations" then path.start_with?("/admin/training_classes") || path.start_with?("/admin/courses") || path.start_with?("/instructors") || path.start_with?("/training_classes") || path.start_with?("/courses")
    when "clients" then path.start_with?("/admin/customers") || path.start_with?("/customers") || path.start_with?("/clients") || (path.start_with?("/admin/customers") && params[:segment].present?)
    when "financials" then path.start_with?("/financials") || path.start_with?("/finance") || path.start_with?("/finance_dashboard") || controller.controller_path.start_with?("financials/") || controller.controller_path == "admin/finance" || controller.controller_path == "admin/exports" || controller.controller_path == "admin/expenses" || controller.controller_path == "admin/compliance" || controller.controller_path == "finance_dashboards"
    when "budget" then path.start_with?("/budget") || controller.controller_path.start_with?("budget/")
    when "strategy" then controller.controller_path == "admin/settings" || path.start_with?("/promotions") || path.start_with?("/insights/strategy")
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

  # Returns "active" or "" for Insights dropdown items. Use with dropdown-item class.
  # path: route helper or string (e.g. insights_business_path, insights_actions_path).
  def insights_nav_item_active?(path)
    request.path == path.to_s ? "active" : ""
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

  # Opens default mail client (e.g. Outlook) with To: = all attendee emails, reminder subject/body
  def mailto_send_reminder_all_attendees(training_class, attendees_list)
    emails = attendees_list.filter_map { |a| a.email.to_s.strip.presence }.compact.uniq
    return "#" if emails.empty?

    subject = "Reminder: #{training_class.title} - #{training_class.date.strftime('%b %d, %Y')}"
    body = "Hi,\n\nReminder for class: #{training_class.title}\n"
    body += "Date: #{training_class.date.strftime('%b %d, %Y')}"
    body += "\nLocation: #{training_class.location}" if training_class.location.present?
    body += "\n\nBest regards"

    encoded_subject = URI.encode_www_form_component(subject)
    encoded_body = URI.encode_www_form_component(body)
    to = emails.join(",")
    "mailto:#{to}?subject=#{encoded_subject}&body=#{encoded_body}"
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

  # Pending-by-class dashboard: priority level and due label for a group hash
  # group: { total_amount:, earliest_due_date:, class_date: }
  def payment_priority_level(group)
    total = group[:total_amount].to_f
    return :none if total.zero?
    due = group[:earliest_due_date] || group[:class_date]
    return :high if due.present? && due < Date.current
    return :medium if due.present? && due >= Date.current && due <= Date.current + 7
    :low
  end

  def payment_due_label(group)
    total = group[:total_amount].to_f
    return "No payment" if total.zero?
    due = group[:earliest_due_date] || group[:class_date]
    return "Overdue" if due.present? && due < Date.current
    if due.present? && due >= Date.current
      days = (due - Date.current).to_i
      return "Due today" if days.zero?
      return "Due in #{days} day".pluralize(days) if days <= 7
    end
    "Upcoming"
  end

  # Group key for pending-by-class sections: :overdue, :due_soon, :upcoming, :none
  def payment_group_key(group)
    total = group[:total_amount].to_f
    return :none if total.zero?
    due = group[:earliest_due_date] || group[:class_date]
    return :overdue if due.present? && due < Date.current
    return :due_soon if due.present? && due >= Date.current && due <= Date.current + 7
    :upcoming
  end

  # Latest reminder sent at for a set of attendee ids (FinancialActionLog send_payment_summary, status: sent)
  def last_reminder_sent_at(attendee_ids)
    return nil if attendee_ids.blank?
    FinancialActionLog
      .where(subject_type: "Attendee", subject_id: attendee_ids, action_type: "send_payment_summary", status: "sent")
      .maximum(:updated_at)
  end

  # Sort link for pending-by-class table: returns path with pfc_sort and pfc_dir toggled for column
  def financials_payments_sort_path(column, base_params = {})
    current = params[:pfc_sort].presence || "priority"
    dir = params[:pfc_dir].presence == "asc" ? "asc" : "desc"
    next_dir = (current == column.to_s && dir == "desc") ? "asc" : "desc"
    financials_payments_path(base_params.merge(pfc_sort: column, pfc_dir: next_dir))
  end

  def financials_payments_sort_indicator(column)
    current = params[:pfc_sort].presence || "priority"
    return "" unless current == column.to_s
    dir = params[:pfc_dir].presence == "asc" ? "asc" : "desc"
    dir == "asc" ? " ↑" : " ↓"
  end

  # Source dropdown options for attendee ledger / inline edits (aligned with Admin::AttendeesController#set_source_channel_options)
  def attendee_source_channel_options
    defaults = %w[Website Facebook Email Line Referral Walk-in Phone Event Direct Internal Web LINE อื่นๆ]
    existing = Attendee.where.not(source_channel: [nil, ""]).distinct.pluck(:source_channel).sort
    (defaults + existing).uniq
  end

  def attendee_ledger_payment_statuses
    %w[Pending Paid Partial Complimentary Refunded Overdue]
  end

  # Effective per-seat base for inline price edit (stored override or class default)
  def attendee_effective_base_price(attendee, training_class)
    stored = attendee.read_attribute(:price)
    if stored.present? && stored.to_f.positive?
      stored.to_f
    else
      training_class.price.to_f
    end
  end

  # Read-only payment pill for attendee ledger (click-to-edit table).
  def ledger_payment_read_badge(attendee)
    s = attendee.payment_status.presence || "Pending"
    case s
    when "Paid"
      odt_badge(s, status: :paid, size: :sm)
    when "Overdue"
      odt_badge(s, status: :overdue, size: :sm)
    when "Pending", "Partial"
      odt_badge(s, status: :pending, size: :sm)
    when "Complimentary", "Refunded"
      odt_badge(s, variant: :neutral, size: :sm)
    else
      odt_badge(s, status: :pending, size: :sm)
    end
  end
end
