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

  # อัปเดตข้อมูลออกเอกสาร (Tax ID, Billing Name, Billing Address) จาก Attendee ที่มีข้อมูลล่าสุด
  # เลือกจาก attendee ที่มี tax_id หรือ name_thai หรือ address (เรียงจาก class ล่าสุด)
  def update_document_info_from_attendees
    att = attendees
           .attendees
           .joins(:training_class)
           .where("attendees.tax_id IS NOT NULL AND attendees.tax_id != '' OR attendees.name_thai IS NOT NULL AND attendees.name_thai != '' OR attendees.address IS NOT NULL AND attendees.address != ''")
           .order("training_classes.date DESC")
           .first
    return false unless att

    self.tax_id = att.tax_id.presence || tax_id
    self.billing_name = att.document_billing_name.presence || billing_name
    self.billing_address = att.address.presence || billing_address
    save
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
