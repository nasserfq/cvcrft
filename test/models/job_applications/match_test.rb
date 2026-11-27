require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::MatchTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  setup { @user = users(:one) }

  test "one match per user and posting" do
    match = create_match(@user)

    duplicate = JobApplications::Match.new(user: @user, posting: match.posting, score: 5)
    assert_has_errors duplicate, :posting_id
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
    assert_valid JobApplications::Match.new(user: users(:two), posting: match.posting, score: 5)
  end

  test "score stays in 1..10" do
    assert_has_errors JobApplications::Match.new(user: @user, posting: create_posting, score: 0), :score
    assert_has_errors JobApplications::Match.new(user: @user, posting: create_posting, score: 11), :score
  end

  test "shown keeps good scores on open postings" do
    good = create_match(@user, score: JobApplications::MIN_SCORE)
    create_match(@user, score: JobApplications::MIN_SCORE - 1)
    create_match(@user, score: 9, posting: create_posting(create_employer, closed_at: 1.hour.ago))

    assert_equal [ good.id ], JobApplications::Match.shown.where(user: @user).pluck(:id)
  end

  test "deleting a posting deletes its matches" do
    match = create_match(@user)
    match.posting.destroy!

    assert_not JobApplications::Match.exists?(match.id)
  end
end
