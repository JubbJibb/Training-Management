class TrainingClass < ApplicationRecord
  has_many :attendees, dependent: :destroy
  
  validates :title, presence: true
  validates :date, presence: true
  validates :location, presence: true
  
  scope :upcoming, -> { where("date >= ?", Date.today).order(:date) }
  scope :past, -> { where("date < ?", Date.today).order(date: :desc) }
end
