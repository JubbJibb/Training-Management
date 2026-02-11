# Preview all emails at http://localhost:3000/rails/mailers/attendee_mailer
class AttendeeMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/attendee_mailer/send_class_info
  def send_class_info
    AttendeeMailer.send_class_info
  end

  # Preview this email at http://localhost:3000/rails/mailers/attendee_mailer/send_reminder
  def send_reminder
    AttendeeMailer.send_reminder
  end

  # Preview this email at http://localhost:3000/rails/mailers/attendee_mailer/send_custom
  def send_custom
    AttendeeMailer.send_custom
  end
end
