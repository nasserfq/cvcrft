class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :resumes, dependent: :destroy
  has_many :work_experiences, through: :resumes
  has_many :skills, through: :resumes
  has_many :ai_translations, dependent: :destroy
  has_many :cv_generations, dependent: :destroy
  has_many :linkedin_imports, dependent: :destroy
  has_many :cv_imports, dependent: :destroy
  has_many :cv_analyses, dependent: :destroy
  has_many :credit_ledger_entries, dependent: :delete_all
  has_many :credit_purchases, dependent: :delete_all
  has_many :coupon_redemptions, dependent: :delete_all

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }

  # CV Generation Statistics
  def cv_generation_count
    cv_generations.count
  end

  def completed_cv_count
    cv_generations.completed.count
  end

  def processing_cv_count
    cv_generations.processing.count
  end

  def failed_cv_count
    cv_generations.failed.count
  end

  def total_tokens_used
    cv_generations.sum(:tokens_used) || 0
  end

  # CV Building Statistics (Resumes)
  def resume_count
    resumes.count
  end

  def resumes_with_work_experience
    resumes.joins(:work_experiences).distinct.count
  end

  def resumes_with_skills
    resumes.joins(:skills).distinct.count
  end

  def resumes_with_ats_score
    resumes.where.not(ats_score: nil).count
  end

  def average_ats_score
    resumes.where.not(ats_score: nil).average(:ats_score)&.round(2) || 0
  end

  def usage_limits
    @usage_limits ||= UserUsageLimits.new(self)
  end
end
