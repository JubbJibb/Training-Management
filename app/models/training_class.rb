class TrainingClass < ApplicationRecord
  has_many :attendees, dependent: :destroy
  has_many :class_expenses, dependent: :destroy
  
  validates :title, presence: true
  validates :date, presence: true
  validates :location, presence: true
  
  def total_expenses
    class_expenses.sum(:amount)
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
