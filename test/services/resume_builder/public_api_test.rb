require "test_helper"

class ResumeBuilder::PublicApiTest < ActiveSupport::TestCase
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @draft = {
      "complete_name" => "Sara Ali",
      "email" => "sara@example.com",
      "phone_number" => "0500000000",
      "city" => "Riyadh",
      "country" => "Saudi Arabia",
      "professional_summary" => "Backend engineer.",
      "professional_summary_english" => "Backend engineer.",
      "work_experience" => [
        { "job_title" => "Engineer", "company" => "Acme", "start_date" => "2020-01", "end_date" => "2023-06",
          "is_current" => false, "responsibilities" => [ "Built APIs", "Led migrations" ] }
      ],
      "education" => [
        { "degree" => "BSc CS", "institution" => "KSU", "start_date" => "2015-09", "end_date" => "2019-06",
          "gpa" => "4.5", "is_current" => false }
      ],
      "skills" => [ { "category" => "Backend", "skill_names" => [ "Ruby", "Postgres" ] } ],
      "certifications" => [ { "name" => "AWS SAA", "organization" => "Amazon", "date" => "2022-03" } ],
      "languages" => [ { "language" => "Arabic", "proficiency" => "Native" } ]
    }
  end

  test "create_from_draft then read round-trips the draft" do
    resume = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft)

    assert_equal false, resume.is_draft
    assert_equal "coach", resume.source
    assert_equal @draft, ResumeBuilder::PublicApi.read(users(:one), resume.id)
  end

  # Catches drift between PublicApi::REQUIRED/FIELDS and what ResumeDraftSync keeps.
  test "a draft built by Coach::Draft survives create_from_draft and read" do
    header = @draft.slice(*Coach::Draft::HEADER)
    draft = Coach::Draft::SECTIONS.reduce({}) do |acc, section|
      Coach::Draft.merge(acc, section, section == "header" ? header : @draft[section])
    end

    resume = ResumeBuilder::PublicApi.create_from_draft(users(:one), draft)

    assert_equal draft, ResumeBuilder::PublicApi.read(users(:one), resume.id).slice(*draft.keys)
  end

  test "read only finds the user's own resumes" do
    resume = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft)

    assert_raises(ActiveRecord::RecordNotFound) { ResumeBuilder::PublicApi.read(users(:two), resume.id) }
  end

  test "list returns only the user's resumes, newest first" do
    older = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft)
    newer = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft.merge("complete_name" => "Sara B"))
    older.update_columns(updated_at: 2.days.ago, title: "Old CV")
    ResumeBuilder::PublicApi.create_from_draft(users(:two), @draft)

    list = ResumeBuilder::PublicApi.list(users(:one))

    assert_equal users(:one).resumes.count, list.size
    assert_equal [ newer.id, older.id ], list.map { |r| r["id"] } & [ newer.id, older.id ]
    assert_equal list.sort_by { |r| r["updated_at"] }.reverse, list
    assert_equal [ "Sara B", "Old CV" ], [ newer.id, older.id ].map { |id| list.find { |r| r["id"] == id }["title"] }
  end
end
