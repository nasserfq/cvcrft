module JobApplications
  # One fetcher per ATS vendor; employers.yml names which one each employer uses.
  module Fetchers
    class FetchError < StandardError; end

    REGISTRY = {
      "greenhouse" => Greenhouse, "lever" => Lever, "ashby" => Ashby,
      "workable" => Workable, "smartrecruiters" => SmartRecruiters, "workday" => Workday
    }.freeze
  end
end
