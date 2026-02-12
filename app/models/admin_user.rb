class AdminUser < ApplicationRecord
  has_secure_password
  has_many :export_jobs, foreign_key: :requested_by_id, dependent: :nullify

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
