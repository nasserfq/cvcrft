require "test_helper"

class CvGenerator::PromptBuilderTest < ActiveSupport::TestCase
  JOB_DESCRIPTION = "Senior Ruby on Rails engineer to lead a payments platform team. Must know PostgreSQL, Sidekiq and AWS.".freeze

  def golden(name)
    File.read(Rails.root.join("test/fixtures/files/cv_generator", name))
  end

  test "new CV prompts equal the golden files" do
    builder = CvGenerator::PromptBuilder.new(job_description: JOB_DESCRIPTION, snapshot: nil)

    assert_equal golden("system_prompt.txt"), builder.system_prompt
    assert_equal golden("user_prompt_new.txt"), builder.user_prompt
  end

  test "existing resume prompts equal the golden files" do
    snapshot = CvGenerator::ResumeSnapshot.new(resumes(:complete_resume)).to_h
    builder = CvGenerator::PromptBuilder.new(job_description: JOB_DESCRIPTION, snapshot: snapshot)

    assert_equal golden("system_prompt.txt"), builder.system_prompt
    assert_equal golden("user_prompt_existing.txt"), builder.user_prompt
  end
end
