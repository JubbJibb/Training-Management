# frozen_string_literal: true

require "test_helper"

class PaymentMailerTest < ActionMailer::TestCase
  setup do
    @training_class = TrainingClass.create!(
      title: "Payment Summary Test Class",
      date: Date.current + 1.week,
      location: "Bangkok",
      price: 1000,
      cost: 0
    )
    @attendee = Attendee.create!(
      training_class: @training_class,
      name: "Mailer Customer",
      email: "customer@example.com",
      participant_type: "Indi",
      seats: 1,
      payment_status: "Pending",
      status: "attendee",
      due_date: Date.current + 1.week
    )
    @pdf_content = "%PDF-1.4 fake pdf content"
    @pdf_filename = "Payment Summary - Test - #{Date.current}.pdf"
  end

  test "payment_summary sends to correct recipient with PDF attached" do
    mail = PaymentMailer.payment_summary(
      attendee: @attendee,
      to: "customer@example.com",
      subject: "Payment Summary — Test Class",
      pdf_content: @pdf_content,
      pdf_filename: @pdf_filename
    )

    assert_equal ["customer@example.com"], mail.to
    assert_equal ["ODTTraining@odds.team"], mail.from
    assert_match /Payment Summary.*Test Class/i, mail.subject
    assert_match @attendee.name, mail.body.encoded
    assert_match @training_class.title, mail.body.encoded
    assert_equal 1, mail.attachments.size
    assert_equal @pdf_filename, mail.attachments.first.filename
    assert_equal "application/pdf", mail.attachments.first.content_type
  end

  test "payment_summary includes due date when unpaid" do
    mail = PaymentMailer.payment_summary(
      attendee: @attendee,
      to: "customer@example.com",
      subject: "Payment Summary",
      pdf_content: @pdf_content,
      pdf_filename: @pdf_filename
    )

    assert_match @attendee.due_date.strftime("%d/%m/%Y"), mail.body.encoded
  end
end
