require "test_helper"

class JobApplications::AiUsageTest < ActiveSupport::TestCase
  U = JobApplications::AiUsage

  test "reserve! takes what is left under the limit and no more" do
    user = users(:one)

    assert_equal 5, U.reserve!(user, :scores, 5, 8)
    assert_equal 3, U.reserve!(user, :scores, 5, 8)
    assert_equal 0, U.reserve!(user, :scores, 5, 8)
    assert_equal 8, U.for(user).scores
  end
end
