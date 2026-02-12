class TrainingClass < ApplicationRecord
  has_many :attendees, dependent: :destroy
  has_many :class_expenses, dependent: :destroy
  
  validates :title, presence: true
  validates :date, presence: true
  validates :location, presence: true
  
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
end
