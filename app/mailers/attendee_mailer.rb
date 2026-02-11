class AttendeeMailer < ApplicationMailer
  # Send class information to a single attendee
  def send_class_info(attendee)
    @attendee = attendee
    @training_class = attendee.training_class
    
    mail(
      to: @attendee.email,
      subject: "Training Class Information: #{@training_class.title}"
    )
  end
  
  # Send reminder to a single attendee
  def send_reminder(attendee)
    @attendee = attendee
    @training_class = attendee.training_class
    
    mail(
      to: @attendee.email,
      subject: "Reminder: #{@training_class.title} - #{@training_class.date.strftime('%B %d, %Y')}"
    )
  end
  
  # Send custom email to a single attendee
  def send_custom(attendee, subject, message)
    @attendee = attendee
    @training_class = attendee.training_class
    @message = message
    
    mail(
      to: @attendee.email,
      subject: subject.presence || "Message regarding #{@training_class.title}"
    )
  end
  
end
