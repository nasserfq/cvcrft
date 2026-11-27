module JobApplications
  # The AI's fit score for one posting and one user. Written once per pair,
  # high or low, so a posting is never scored twice.
  class Match < ApplicationRecord
    belongs_to :user
    belongs_to :posting, class_name: "JobApplications::Posting", inverse_of: :matches

    validates :score, inclusion: { in: 1..10 }
    validates :posting_id, uniqueness: { scope: :user_id }

    # What "Jobs for you" lists: good scores on postings still open.
    scope :shown, -> { where(score: MIN_SCORE..).joins(:posting).merge(Posting.open) }
  end
end
