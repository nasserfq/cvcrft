class User < ApplicationRecord
  has_many :resumes, dependent: :destroy
  has_many :work_experiences, through: :resumes
  has_many :skills, through: :resumes
  has_many :ai_translations, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  
  # Add secure password if using authentication
  # has_secure_password
end
