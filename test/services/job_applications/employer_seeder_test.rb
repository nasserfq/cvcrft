require "test_helper"

class JobApplications::EmployerSeederTest < ActiveSupport::TestCase
  E = JobApplications::Employer

  test "creates employers from the file" do
    result = JobApplications::EmployerSeeder.call(file_fixture("employers.yml"))

    assert_equal({ created: 3, updated: 0, deactivated: 0, invalid: [] }, result)
    desert = E.find_by!(ats: "workday", identifier: "desert")
    assert_equal [ "desert.wd3.myworkdayjobs.com", "Careers", "SA", false, true ], [ desert.host, desert.site, desert.country, desert.verified, desert.active ]
  end

  test "a second run updates changed entries only" do
    JobApplications::EmployerSeeder.call(file_fixture("employers.yml"))
    E.find_by!(identifier: "acme").update!(name: "Old name")

    result = JobApplications::EmployerSeeder.call(file_fixture("employers.yml"))

    assert_equal [ 0, 1 ], [ result[:created], result[:updated] ]
    assert_equal "Acme Riyadh", E.find_by!(identifier: "acme").name
  end

  test "deactivates employers missing from the file and skips invalid entries" do
    gone = E.create!(name: "Gone", ats: "lever", identifier: "gone")
    path = Rails.root.join("tmp/employers-#{SecureRandom.hex(4)}.yml")
    File.write(path, [ { "name" => "Acme", "ats" => "greenhouse", "identifier" => "acme" },
                       { "name" => "Bad", "ats" => "taleo", "identifier" => "bad" },
                       { "name" => "No site", "ats" => "workday", "identifier" => "nosite" } ].to_yaml)

    result = JobApplications::EmployerSeeder.call(path)

    assert_equal [ 1, 1 ], [ result[:created], result[:deactivated] ]
    assert_equal 2, result[:invalid].size
    assert_not gone.reload.active
  ensure
    FileUtils.rm_f(path)
  end
end
