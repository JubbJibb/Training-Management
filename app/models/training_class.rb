class TrainingClass < ApplicationRecord
  include TrainingClassPublicSlug

  CLASS_STATUSES = %w[public private tentative].freeze

  has_many :attendees, dependent: :destroy
  has_many :class_expenses, dependent: :destroy
  belongs_to :internal_notes_updated_by, class_name: "AdminUser", optional: true

  serialize :related_links, coder: JSON
  serialize :checklist_items, coder: JSON
  serialize :notes, coder: JSON

  validates :title, presence: true
  validates :date, presence: true
  validates :location, presence: true
  validates :class_status, presence: true, inclusion: { in: CLASS_STATUSES }

  before_save :sync_public_enabled_from_class_status

  # Public page is only enabled when class status is "public"
  def public_enabled?
    class_status == "public"
  end

  def total_expenses
    class_expenses.sum(:amount)
  end

  # Total seats taken by registered attendees (sum of attendee.seats, not just headcount)
  def total_registered_seats
    attendees.attendees.sum(:seats)
  end
  
  def total_cost
    (cost.to_f + total_expenses).round(2)
  end
  
  scope :upcoming, -> { 
    where("date >= ? OR (end_date IS NOT NULL AND end_date >= ?)", Date.today, Date.today).order(:date) 
  }
  scope :past, -> {
    where("date < ? AND (end_date IS NULL OR end_date < ?)", Date.today, Date.today).order(date: :desc)
  }

  # Placeholder until cancelled_at or status column exists
  scope :cancelled, -> { none }

  def fill_rate_percent
    return nil if max_attendees.blank? || max_attendees.zero?
    (total_registered_seats.to_f / max_attendees * 100).round(0)
  end

  def net_revenue
    attendees.attendees.sum(&:total_final_price)
  end

  def status_label
    return "Cancelled" if respond_to?(:cancelled?) && cancelled?
    return "Past" if date < Date.today || (end_date.present? && end_date < Date.today)
    "Upcoming"
  end

  # For command bar status pill: Draft / Scheduled / Completed
  def status_pill
    return "Cancelled" if respond_to?(:cancelled?) && cancelled?
    return "Completed" if date < Date.today || (end_date.present? && end_date < Date.today)
    "Scheduled"
  end

  def outstanding_amount
    attendees.attendees.select { |a| a.payment_status != "Paid" }.sum(&:total_final_price)
  end

  def duration
    # Calculate duration in days
    # Use end_date if available, otherwise use date (single day class)
    end_date_value = end_date || date
    
    # Calculate number of days (inclusive of both start and end date)
    days = (end_date_value - date).to_i + 1
    
    if days == 1
      "1 Day"
    else
      "#{days} days"
    end
  end
  
  def duration_in_days
    end_date_value = end_date || date
    (end_date_value - date).to_i + 1
  end

  # Related links, checklist, notes (JSON columns)
  def related_links
    super.presence || []
  end

  def checklist_items
    super.presence || []
  end

  def notes
    super.presence || []
  end

  def checklist_done_count
    checklist_items.count { |i| i["done"] == true }
  end

  def checklist_total_count
    checklist_items.size
  end

  private

  def sync_public_enabled_from_class_status
    self.public_enabled = (class_status == "public") if class_status.present?
  end
end
