require "test_helper"

class JobApplications::ApplyEmailTest < ActiveSupport::TestCase
  def from(text) = JobApplications::ApplyEmail.from(text)

  test "a mailto wins over any other address" do
    assert_equal "jobs@acme.com", from("Questions: info@acme.com. Apply: mailto:Jobs@Acme.com")
  end

  test "an address near an apply keyword, in English or Arabic" do
    assert_equal "careers@acme.sa", from("Please send your CV to careers@acme.sa.")
    assert_equal "hr@acme.sa", from("hr@acme.sa لإرسال السيرة الذاتية")
    assert_equal "talent@acme.com", from("Interested? talent@acme.com is where to apply.")
  end

  test "an address far from any keyword is ignored" do
    assert_nil from("Apply now. #{'Lorem ipsum dolor. ' * 10}Office: office@acme.com")
  end

  test "no-reply and image-like addresses are dropped" do
    assert_nil from("Send your CV to noreply@acme.com")
    assert_nil from("Send your CV mailto:do-not-reply@acme.com")
    assert_nil from("Apply here logo@2x.png")
    assert_equal "jobs@acme.com", from("Do not apply to no-reply@acme.com, send your CV to jobs@acme.com")
  end

  test "nil when there is no address" do
    assert_nil from("Own the roadmap and apply on our site.")
    assert_nil from(nil)
    assert_nil from("")
  end
end
