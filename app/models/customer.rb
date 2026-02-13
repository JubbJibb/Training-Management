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

  # Billing & Tax (QT/INV/Receipt) completeness for directory icons
  def billing_tax_status
    {
      tax_id: tax_id.present?,
      billing_name: billing_name.present?,
      billing_address: billing_address.present?
    }
  end

  def billing_tax_missing_fields
    %i[tax_id billing_name billing_address].select { |k| send(k).blank? }
  end

  # Short strings for tooltips (e.g. "1102…9061", first 40 chars of address)
  def billing_tax_present_values_short
    tax_short = if tax_id.present?
      tax_id.length >= 9 ? "#{tax_id[0, 4]}…#{tax_id[-4, 4]}" : tax_id
    end
    {
      tax_id: tax_short,
      billing_name: billing_name.presence,
      billing_address: billing_address.present? ? (billing_address.length > 40 ? "#{billing_address[0, 40]}…" : billing_address) : nil
    }
  end

  # อัปเดตข้อมูลออกเอกสาร (Tax ID, Billing Name, Billing Address, Name Thai, Address) จาก Attendee ที่มีข้อมูลล่าสุด
  def update_document_info_from_attendees
    cond = "attendees.tax_id IS NOT NULL AND attendees.tax_id != '' OR attendees.name_thai IS NOT NULL AND attendees.name_thai != '' OR attendees.address IS NOT NULL AND attendees.address != ''"
    cond += " OR attendees.billing_name IS NOT NULL AND attendees.billing_name != '' OR attendees.billing_address IS NOT NULL AND attendees.billing_address != ''" if Attendee.column_names.include?("billing_name")
    att = attendees.attendees.joins(:training_class).where(cond).order("training_classes.date DESC").first
    return false unless att

    self.tax_id = att.tax_id.presence || tax_id
    self.billing_name = att.document_billing_name.presence || billing_name
    self.billing_address = (att.respond_to?(:document_billing_address) ? att.document_billing_address : att.address).presence || billing_address
    self.name_thai = att.name_thai.presence || name_thai if respond_to?(:name_thai=)
    addr_src = att.respond_to?(:billing_address) && att.billing_address.present? ? att.billing_address : att.address
    self.address = addr_src.presence || address if respond_to?(:address=)
    save
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
