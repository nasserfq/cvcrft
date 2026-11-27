require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::PostingTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  def posting(attrs = {})
    JobApplications::Posting.new({ employer: create_employer, external_id: "1", title: "Nurse", fetched_at: Time.current,
                                   url: "https://jobs.lever.co/acme/1", apply_url: "http://jobs.lever.co/acme/1/apply" }.merge(attrs))
  end

  test "http and https links are valid" do
    assert_valid posting
  end

  test "links must be absolute http(s) URLs with a host" do
    assert_has_errors posting(url: "javascript:alert(1)"), :url
    assert_has_errors posting(url: "data:text/html;base64,PHNjcmlwdD4="), :url
    assert_has_errors posting(url: "/jobs/1"), :url
    assert_has_errors posting(url: "https://"), :url
    assert_has_errors posting(apply_url: "JavaScript:alert(1)"), :apply_url
  end
end
