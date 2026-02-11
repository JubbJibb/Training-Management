require "test_helper"

class AttendeeMailerTest < ActionMailer::TestCase
  test "send_class_info" do
    mail = AttendeeMailer.send_class_info
    assert_equal "Send class info", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "send_reminder" do
    mail = AttendeeMailer.send_reminder
    assert_equal "Send reminder", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "send_custom" do
    mail = AttendeeMailer.send_custom
    assert_equal "Send custom", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
