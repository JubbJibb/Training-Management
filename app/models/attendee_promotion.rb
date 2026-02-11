class AttendeePromotion < ApplicationRecord
  belongs_to :attendee
  belongs_to :promotion
end
