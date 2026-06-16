require "test_helper"

class ResumeDraftDeduplicatorTest < ActiveSupport::TestCase
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @user = users(:one)
  end

  test "removes duplicate empty starter drafts and keeps the most recently updated" do
    older = create_starter_draft(updated_at: 2.days.ago)
    newer = create_starter_draft(updated_at: 1.hour.ago)

    removed = ResumeDraftDeduplicator.call(@user)

    assert_equal 1, removed
    assert Resume.exists?(newer.id)
    assert_not Resume.exists?(older.id)
  end

  test "treats empty starter drafts as duplicates even when draft_data differs" do
    older = create_starter_draft(
      updated_at: 2.days.ago,
      draft_data: {}
    )
    newer = create_starter_draft(
      updated_at: 1.hour.ago,
      draft_data: production_like_draft_data
    )

    removed = ResumeDraftDeduplicator.call(@user)

    assert_equal 1, removed
    assert Resume.exists?(newer.id)
    assert_not Resume.exists?(older.id)
  end

  test "collapses many production-like duplicate drafts to one" do
    drafts = 5.times.map do |i|
      create_starter_draft(
        updated_at: i.days.ago,
        draft_data: production_like_draft_data
      )
    end

    removed = ResumeDraftDeduplicator.call(@user)

    assert_equal 4, removed
    assert_equal 1, @user.resumes.drafts.where(email: "starter@example.com").count
    assert Resume.exists?(drafts.first.id)
  end

  test "keeps drafts with different meaningful draft data" do
    first = create_starter_draft(
      draft_data: {
        "current_step" => 1,
        "work_experience" => [ { "company" => "Acme", "job_title" => "Engineer" } ].to_json
      }
    )
    second = create_starter_draft(
      draft_data: {
        "current_step" => 1,
        "work_experience" => [ { "company" => "Beta", "job_title" => "Designer" } ].to_json
      }
    )

    removed = ResumeDraftDeduplicator.call(@user)

    assert_equal 0, removed
    assert Resume.exists?(first.id)
    assert Resume.exists?(second.id)
  end

  test "does not remove completed resumes" do
    draft = create_starter_draft
    completed = Resume.create!(
      user: @user,
      complete_name: draft.complete_name,
      email: draft.email,
      is_draft: false
    )

    removed = ResumeDraftDeduplicator.call(@user)

    assert_equal 0, removed
    assert Resume.exists?(draft.id)
    assert Resume.exists?(completed.id)
  end

  private

  def create_starter_draft(attrs = {})
    defaults = {
      user: @user,
      complete_name: "starter-user",
      email: "starter@example.com",
      is_draft: true,
      draft_data: { "current_step" => 1 }
    }

    Resume.create!(defaults.merge(attrs))
  end

  def production_like_draft_data
    {
      "current_step" => 1,
      "complete_name" => "starter-user",
      "email" => "starter@example.com",
      "education" => [ { "degree" => "", "institution" => "" } ].to_json,
      "work_experience" => [ { "job_title" => "", "company" => "", "responsibilities" => [ "" ] } ].to_json,
      "skills" => [ { "category" => "", "skill_names" => [] } ].to_json,
      "certifications" => [ { "name" => "", "organization" => "" } ].to_json,
      "languages" => [ { "language" => "", "proficiency" => "" } ].to_json
    }
  end
end
