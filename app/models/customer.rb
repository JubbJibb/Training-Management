class Customer < ApplicationRecord
  has_many :attendees, dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  before_validation :normalize_email

  # Excel-style mapping (for QT/INV/Receipt)
  # - Company Name: billing_name (preferred) -> company -> name
  # - Company Address: billing_address
  # - Contact Person: name
  def company_name
    billing_name.presence || company.presence || name
  end

  def company_address
    billing_address
  end

  def contact_person
    name
  end

  # Number of distinct classes that this customer actually registered (status=attendee)
  def classes_attended_count
    attendees.attendees.select(:training_class_id).distinct.count
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
