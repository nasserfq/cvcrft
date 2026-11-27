require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::FetchersTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  F = JobApplications::Fetchers

  def employer(attrs = {})
    JobApplications::Employer.new({ name: "Acme", ats: "greenhouse", identifier: "acme", country: "SA" }.merge(attrs))
  end

  test "greenhouse keeps Gulf postings and turns HTML into text" do
    fetcher = F::Greenhouse.new(employer)
    fetcher.stubs(:http_get).with("https://boards-api.greenhouse.io/v1/boards/acme/jobs?content=true").returns(ats_fixture("greenhouse"))

    postings = fetcher.call

    assert_equal %w[101 103], postings.map(&:external_id)
    pm = postings.first
    assert_kind_of F::Base::Posting, pm
    assert_equal [ "Senior Product Manager", "Riyadh, Saudi Arabia", "SA" ], [ pm.title, pm.location, pm.country ]
    assert_equal "Own the roadmap.", pm.description
    assert_equal pm.url, pm.apply_url
    assert_equal "AE", postings.last.country
  end

  test "lever reads the plain description and skips non-Gulf jobs" do
    fetcher = F::Lever.new(employer(ats: "lever", identifier: "gulflever", country: "AE"))
    fetcher.stubs(:http_get).returns(ats_fixture("lever"))

    posting = fetcher.call.sole

    assert_equal [ "lv-1", "Marketing Lead", "AE" ], [ posting.external_id, posting.title, posting.country ]
    assert_equal "Lead marketing in the Gulf.", posting.description
    assert_equal "https://jobs.lever.co/gulflever/lv-1/apply", posting.apply_url
    assert_not_nil posting.posted_at
  end

  test "ashby drops unlisted and non-Gulf jobs" do
    fetcher = F::Ashby.new(employer(ats: "ashby"))
    fetcher.stubs(:http_get).returns(ats_fixture("ashby"))

    posting = fetcher.call.sole

    assert_equal [ "ab-1", "QA" ], [ posting.external_id, posting.country ]
  end

  test "workable widget picks the Gulf location of a multi-location job" do
    fetcher = F::Workable.new(employer(ats: "workable"))
    fetcher.stubs(:http_get).returns(ats_fixture("workable_widget"))

    posting = fetcher.call.sole

    assert_equal [ "AB12CD", "Riyadh, Saudi Arabia", "SA" ], [ posting.external_id, posting.location, posting.country ]
    assert_equal "Books.", posting.description
  end

  test "workable falls back to the paged v3 list when the widget fails" do
    fetcher = F::Workable.new(employer(ats: "workable"))
    fetcher.stubs(:http_get).raises(F::FetchError, "HTTP 404")
    fetcher.expects(:http_post).twice.returns(ats_fixture("workable_v3_page1"), ats_fixture("workable_v3_page2"))

    posting = fetcher.call.sole

    assert_equal [ "V3A", "Jeddah, Saudi Arabia" ], [ posting.external_id, posting.location ]
    assert_equal "https://apply.workable.com/acme/j/V3A/apply/", posting.apply_url
  end

  test "smartrecruiters reads every page" do
    fetcher = F::SmartRecruiters.new(employer(ats: "smartrecruiters"))
    fetcher.expects(:http_get).with(regexp_matches(/offset=0\z/)).returns(ats_fixture("smartrecruiters_page1"))
    fetcher.expects(:http_get).with(regexp_matches(/offset=100\z/)).returns(ats_fixture("smartrecruiters_page2"))

    posting = fetcher.call.sole

    assert_equal [ "sr-1", "Al Khobar, sa", "SA" ], [ posting.external_id, posting.location, posting.country ]
    assert_equal "https://jobs.smartrecruiters.com/acme/sr-1", posting.url
  end

  test "workday reads every page and dates 'Posted 3 Days Ago'" do
    fetcher = F::Workday.new(employer(ats: "workday", identifier: "desert", host: "desert.wd3.myworkdayjobs.com", site: "Careers"))
    fetcher.expects(:http_post).twice.returns(ats_fixture("workday_page1"), ats_fixture("workday_page2"))

    posting = fetcher.call.sole

    assert_equal [ "R100", "Process Engineer", "SA" ], [ posting.external_id, posting.title, posting.country ]
    assert_equal "https://desert.wd3.myworkdayjobs.com/en-US/Careers/job/Jubail/Process-Engineer_R100", posting.url
    assert_equal 3.days.ago.beginning_of_day.to_date, posting.posted_at.to_date
  end

  test "workday without host and site raises" do
    assert_raises(F::FetchError) { F::Workday.new(employer(ats: "workday")).call }
  end
end
