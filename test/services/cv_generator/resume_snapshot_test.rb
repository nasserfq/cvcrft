require "test_helper"

class CvGenerator::ResumeSnapshotTest < ActiveSupport::TestCase
  def snapshot(resume)
    CvGenerator::ResumeSnapshot.new(resume).to_h
  end

  test "nil gives an empty hash" do
    assert_equal({}, snapshot(nil))
  end

  test "the fixture resume matches the golden snapshot" do
    golden = JSON.parse(File.read(Rails.root.join("test/fixtures/files/cv_generator/snapshot_complete_resume.json")))

    assert_equal golden, snapshot(resumes(:complete_resume)).deep_stringify_keys
  end

  test "string responsibilities are split on newlines and blank lines dropped" do
    work_experiences(:past_job).update_columns(responsibilities: "Built APIs\n\nShipped features\n")

    past = snapshot(resumes(:complete_resume))[:work_experiences].find { |e| e[:company] == "Digital Agency" }
    assert_equal [ "Built APIs", "Shipped features" ], past[:responsibilities]
  end

  test "Array responsibilities pass through and non-strings give an empty list" do
    exp = Struct.new(:job_title, :company, :start_date, :end_date, :is_current, :responsibilities)
    resume = Struct.new(:professional_summary, :work_experiences, :skills, :educations, :certifications, :languages)
                   .new("S", [ exp.new("A", "B", "2020-01", "2021-01", false, [ "one", "two" ]),
                               exp.new("C", "D", "2019-01", "2020-01", false, nil) ], [], [], [], [])

    assert_equal [ [ "one", "two" ], [] ], snapshot(resume)[:work_experiences].map { |e| e[:responsibilities] }
  end

  test "a current job ends in Present" do
    current = snapshot(resumes(:complete_resume))[:work_experiences].find { |e| e[:company] == "Tech Solutions Inc" }

    assert_equal "Present", current[:end_date]
  end

  test "skills are grouped by category with their names joined into details" do
    resume = resumes(:complete_resume)
    resume.skills.create!(category: "technical", name: "Go", skill_names: [ "Go", "Rust" ])
    resume.skills.create!(category: "technical", name: "Elixir", skill_names: [ "" ]).update_columns(skill_names: nil)

    technical = snapshot(resume)[:skills].find { |s| s[:category] == "technical" }
    assert_equal [ "Ruby", "JavaScript", "Python", "SQL", "Go", "Rust", "Elixir" ], technical[:names]
    assert_equal "Ruby, JavaScript, Python, SQL, Go, Rust, Elixir", technical[:details]
  end

  test "gpa is left out when blank" do
    educations(:masters).update_columns(gpa: nil)

    masters = snapshot(resumes(:complete_resume))[:educations].find { |e| e[:institution] == "Stanford University" }
    assert_not masters.key?(:gpa)
  end
end
