class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :trackable
  # :omniauthable covers social sign-in for the providers SocialAuth has on.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: SocialAuth.providers
  has_many :identities, class_name: "UserIdentity", dependent: :destroy
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

  # PDPL: the user accepted the current privacy policy and terms.
  def record_privacy_consent!
    update_columns(privacy_accepted_at: Time.current, privacy_policy_version: PrivacyPolicy::VERSION)
  end

  def usage_limits
    @usage_limits ||= UserUsageLimits.new(self)
  end
end
