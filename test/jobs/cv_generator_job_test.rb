require "test_helper"

# Characterization tests: written against the job before it was split into
# CvGenerator::* objects, so they pin what it does today.
class CvGeneratorJobTest < ActiveSupport::TestCase
  JOB_DESCRIPTION = "Senior Ruby on Rails engineer to lead a payments platform team. Must know PostgreSQL, Sidekiq and AWS.".freeze
  GOLDEN_DIR = Rails.root.join("test/fixtures/files/cv_generator")

  AI_REPLY = {
    professional_summary: "Seasoned Rails engineer who ships payment systems.",
    work_experiences: [
      { job_title: "Lead Engineer", company: "PayCo", start_date: "2021-01", end_date: nil, responsibilities: [ "Led a team of six" ] }
    ],
    skills: [ { category: "Technical Skills", names: [ "Ruby", "Rails" ] } ],
    educations: [ { degree: "BSc Computer Science", institution: "KSU", start_date: "2010-09", end_date: "2014-06" } ],
    certifications: [ { name: "AWS SA", organization: "Amazon", date: "2020-01" } ],
    languages: [ { language: "English", proficiency: "Fluent" } ],
    ats_optimization_notes: "Keyword dense",
    generation_notes: "Tailored to payments"
  }.freeze

  setup do
    stub_pdf_generation
    @pdf_file = Tempfile.new([ "cv", ".pdf" ])
    @pdf_file.write("%PDF-fake")
    @pdf_file.flush
    AtsTemplatePdfService.stubs(:generate_pdf).returns({ path: @pdf_file.path, filename: "generated_cv.pdf" })
  end

  teardown do
    @pdf_file.close!
  end

  def golden(name)
    File.read(GOLDEN_DIR.join(name))
  end

  def snapshot_golden
    JSON.parse(golden("snapshot_complete_resume.json"))
  end

  def ai_message(content, tokens: 800)
    text = content.is_a?(String) ? content : content.to_json
    usage = Struct.new(:input, :output).new(tokens / 2, tokens - (tokens / 2))
    Struct.new(:content, :tokens).new(text, usage)
  end

  def run_job(user, resume_id = nil, options = {})
    CvGeneratorJob.new.perform(JOB_DESCRIPTION, user.id, resume_id, options)
  end

  def last_generation(user)
    user.cv_generations.where(job_description: JOB_DESCRIPTION).order(:id).last
  end

  test "without a saved resume nothing is created and the queued generation is marked failed" do
    user = users(:test_user)
    queued = create_test_cv_generation(user, job_description: JOB_DESCRIPTION)
    AiModel.expects(:complete).never

    assert_no_difference [ -> { user.resumes.count }, -> { CvGeneration.count } ] do
      error = assert_raises(ArgumentError) { run_job(user, nil, { "complete_name" => "Sara Ali" }) }
      assert_equal "resume_id is required", error.message
    end

    queued.reload
    assert_equal "failed", queued.status
    assert_equal "resume_id is required", queued.metadata["error"]
    assert_nil queued.resume_id
  end

  test "without a saved resume and no queued generation, no record of any kind is created" do
    user = users(:test_user)
    AiModel.expects(:complete).never

    assert_no_difference [ -> { user.resumes.count }, -> { CvGeneration.count } ] do
      assert_raises(ArgumentError) { run_job(user, "") }
    end
  end

  test "existing resume: keeps the resume untouched and stores its snapshot with the new summary" do
    user = users(:user_with_resumes)
    resume = resumes(:complete_resume)
    before = {
      updated_at: resume.updated_at, summary: resume.professional_summary,
      counts: [ resume.work_experiences.count, resume.skills.count, resume.educations.count,
                resume.certifications.count, resume.languages.count ]
    }
    stub_ai_response(AI_REPLY, tokens: 900)

    freeze_time do
      assert_no_difference -> { user.resumes.count } do
        run_job(user, resume.id)
      end

      generation = last_generation(user)
      assert_equal "completed", generation.status
      assert_equal resume.id, generation.resume_id
      assert_equal AI_REPLY[:professional_summary], generation.generated_content
      assert_equal 900, generation.tokens_used

      meta = generation.metadata
      # Only the summary comes from the AI; every other section is the saved resume's.
      saved_sections = JSON.parse(CvGenerator::ResumeSnapshot.new(resume).to_h.except(:professional_summary).to_json)
      assert_equal saved_sections, meta["generated_data"].except("professional_summary")
      assert_not_equal resume.professional_summary, meta["generated_data"]["professional_summary"]
      expected_data = snapshot_golden.merge("professional_summary" => AI_REPLY[:professional_summary])
      assert_equal expected_data, meta["generated_data"]
      assert_equal Base64.encode64("%PDF-fake"), meta["pdf_data"]
      assert_match(/\A\h{32}\z/, meta["pdf_cache_key"])
      assert_equal({
        "force_pdf_regeneration" => false,
        "pdf_cache_hours" => 24,
        "generated_data" => expected_data,
        "ats_optimization_notes" => "Preserved all existing resume data",
        "generation_notes" => "Updated only professional summary while preserving all existing data",
        "raw_response" => AI_REPLY.to_json,
        "ats_template" => "original_classic",
        "pdf_generated" => true,
        "pdf_filename" => "generated_cv.pdf",
        "pdf_size" => 9,
        "pdf_version" => "2.1",
        "pdf_generated_at" => Time.now.to_i
      }, meta.except("pdf_data", "pdf_cache_key"))
    end

    resume.reload
    assert_equal before[:updated_at], resume.updated_at
    assert_equal before[:summary], resume.professional_summary
    assert_equal before[:counts], [ resume.work_experiences.count, resume.skills.count, resume.educations.count,
                                    resume.certifications.count, resume.languages.count ]
  end

  test "existing resume: the PDF is rendered from the stored data with the chosen template" do
    user = users(:user_with_resumes)
    resume = resumes(:complete_resume)
    stub_ai_response(AI_REPLY)
    expected = snapshot_golden.merge("professional_summary" => AI_REPLY[:professional_summary]).deep_symbolize_keys
    AtsTemplatePdfService.expects(:generate_pdf)
                         .with(resume, expected, template: "harvard_classic")
                         .returns({ path: @pdf_file.path, filename: "generated_cv.pdf" })

    run_job(user, resume.id, { "ats_template" => "harvard_classic" })

    assert_equal "harvard_classic", last_generation(user).metadata["ats_template"]
  end

  test "a processing generation for the same job description is reused, its metadata kept and its template used" do
    user = users(:user_with_resumes)
    existing = create_test_cv_generation(user, job_description: JOB_DESCRIPTION, metadata: { "source" => "form", "ats_template" => "harvard_classic" })
    stub_ai_response(AI_REPLY)

    assert_no_difference -> { CvGeneration.count } do
      run_job(user, resumes(:complete_resume).id)
    end

    existing.reload
    assert_equal "completed", existing.status
    assert_equal "form", existing.metadata["source"]
    assert_equal "harvard_classic", existing.metadata["ats_template"]
    assert existing.metadata["generated_data"].present?
  end

  test "fenced JSON in the reply is unwrapped" do
    user = users(:user_with_resumes)
    fenced = "```json\n#{AI_REPLY.to_json}\n```"
    stub_ai_response(fenced)

    run_job(user, resumes(:complete_resume).id)

    generation = last_generation(user)
    assert_equal AI_REPLY[:professional_summary], generation.generated_content
    assert_equal AI_REPLY.to_json, generation.metadata["raw_response"]
    assert_equal "Preserved all existing resume data", generation.metadata["ats_optimization_notes"]
  end

  test "AI failure marks the generation failed and re-raises" do
    user = users(:user_with_resumes)
    resume = resumes(:complete_resume)
    stub_ai_failure

    error = assert_raises(RuntimeError) { run_job(user, resume.id) }
    assert_equal "API Error", error.message

    generation = last_generation(user)
    assert_equal "failed", generation.status
    assert_equal "API Error", generation.metadata["error"]
    assert generation.metadata["error_backtrace"].present?
    assert_equal resume.id, generation.resume_id
  end

  test "another user's resume is refused and the run marked failed" do
    stub_ai_response(AI_REPLY)
    AiModel.expects(:complete).never

    assert_raises(ActiveRecord::RecordNotFound) { run_job(users(:test_user), resumes(:complete_resume).id) }
    assert_equal "failed", last_generation(users(:test_user)).status
  end

  test "existing resume sends the golden prompts" do
    AiModel.expects(:complete)
           .with(system: golden("system_prompt.txt"), user: golden("user_prompt_existing.txt"), temperature: 0.7, max_tokens: 15000)
           .returns(ai_message(AI_REPLY))

    run_job(users(:user_with_resumes), resumes(:complete_resume).id)
  end

  test "temperature and max_tokens come from the options" do
    AiModel.expects(:complete)
           .with(has_entries(temperature: 0.2, max_tokens: 4000))
           .returns(ai_message(AI_REPLY))

    run_job(users(:user_with_resumes), resumes(:complete_resume).id, { "temperature" => "0.2", "max_tokens" => "4000" })
  end
end
