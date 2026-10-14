require "test_helper"

class Coach::DraftTest < ActiveSupport::TestCase
  JOB = { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01", "responsibilities" => [ "Served customers" ] }.freeze

  test "an unknown section raises" do
    error = assert_raises(Coach::Draft::Invalid) { Coach::Draft.merge({}, "hobbies", []) }
    assert_includes error.message, "work_experience"
  end

  test "a work_experience entry without company raises" do
    error = assert_raises(Coach::Draft::Invalid) do
      Coach::Draft.merge({}, "work_experience", [ JOB.except("company") ])
    end
    assert_includes error.message, "company"
  end

  test "skills with a String skill_names raises" do
    assert_raises(Coach::Draft::Invalid) do
      Coach::Draft.merge({}, "skills", [ { "category" => "Retail", "skill_names" => "Cash handling" } ])
    end
  end

  test "a collection replaces the old one and drops unknown keys" do
    draft = { "complete_name" => "Sara", "work_experience" => [ JOB.merge("company" => "Old") ] }

    merged = Coach::Draft.merge(draft, "work_experience", [ JOB.merge("salary" => "5000") ])

    assert_equal({ "complete_name" => "Sara", "work_experience" => [ JOB ] }, merged)
  end

  test "header keeps only the contact fields, flat in the draft" do
    merged = Coach::Draft.merge({}, "header", { "complete_name" => "Sara", "email" => "s@example.com", "age" => "30" })

    assert_equal({ "complete_name" => "Sara", "email" => "s@example.com" }, merged)
  end

  test "professional_summary must be a non-empty string" do
    assert_raises(Coach::Draft::Invalid) { Coach::Draft.merge({}, "professional_summary", " ") }
    assert_equal({ "professional_summary" => "Cashier." }, Coach::Draft.merge({}, "professional_summary", "Cashier."))
  end
end
