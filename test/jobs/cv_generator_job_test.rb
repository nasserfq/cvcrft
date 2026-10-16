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

  test "new CV from a non-JSON reply: creates a resume and stores the raw text as the summary" do
    user = users(:test_user)
    stub_ai_response("Plain text summary, no JSON here.", tokens: 640)

    assert_difference -> { user.resumes.count }, 1 do
      run_job(user, nil, { "complete_name" => "Sara Ali", "email" => "sara@example.com" })
    end

    generation = last_generation(user)
    assert_equal "completed", generation.status
    assert_equal "Plain text summary, no JSON here.", generation.generated_content
    assert_equal 640, generation.tokens_used
    assert_equal AiModel.default, generation.ai_model

    meta = generation.metadata
    assert_equal({
      "professional_summary" => "Plain text summary, no JSON here.",
      "work_experiences" => [], "skills" => [], "educations" => [], "certifications" => [], "languages" => []
    }, meta["generated_data"])
    assert_equal "Response was not in expected JSON format", meta["ats_optimization_notes"]
    assert_equal "Response was not in expected JSON format", meta["generation_notes"]
    assert_equal "Plain text summary, no JSON here.", meta["raw_response"]
    assert_equal "Sara Ali", meta["complete_name"]
    assert_equal true, meta["pdf_generated"]

    resume = generation.resume
    assert_equal "Sara Ali", resume.complete_name
    assert_equal "sara@example.com", resume.email
    assert_equal "Plain text summary, no JSON here.", resume.professional_summary
    assert_equal "Plain text summary, no JSON here.", resume.summary
    assert_equal 0, resume.work_experiences.count
    assert_equal 0, resume.skills.count
  end

  test "new CV defaults the name and email when options leave them out" do
    user = users(:test_user)
    stub_ai_response("Summary only")

    run_job(user)

    resume = last_generation(user).resume
    assert_equal "Generated CV", resume.complete_name
    assert_equal "user@example.com", resume.email
  end

  test "new CV saves every section of the reply onto the new resume" do
    user = users(:test_user)
    stub_ai_response(AI_REPLY)

    assert_difference -> { user.resumes.count }, 1 do
      run_job(user)
    end

    generation = last_generation(user)
    assert_equal "completed", generation.status
    assert_equal AI_REPLY[:professional_summary], generation.generated_content
    assert_equal JSON.parse(AI_REPLY.except(:ats_optimization_notes, :generation_notes).to_json),
                 generation.metadata["generated_data"]
    assert_equal "Keyword dense", generation.metadata["ats_optimization_notes"]

    resume = generation.resume
    assert_equal AI_REPLY[:professional_summary], resume.professional_summary
    assert_equal [ [ "PayCo", "Lead Engineer", "2021-01", nil, [ "Led a team of six" ].to_s ] ],
                 resume.work_experiences.pluck(:company, :job_title, :start_date, :end_date, :responsibilities)
    assert_equal [ [ "BSc Computer Science", "KSU", "2010-09", "2014-06" ] ],
                 resume.educations.pluck(:degree, :institution, :start_date, :end_date)
    assert_equal [ [ "Technical Skills", "Ruby", [ "Ruby" ] ], [ "Technical Skills", "Rails", [ "Rails" ] ] ],
                 resume.skills.order(:id).map { |skill| [ skill.category, skill.name, skill.skill_names ] }
    assert_equal [ [ "AWS SA", "Amazon", "2020-01" ] ], resume.certifications.pluck(:name, :organization, :date)
    assert_equal [ [ "English", "Fluent" ] ], resume.languages.pluck(:language, :proficiency)
  end

  test "new CV with only skills in the reply saves the skills" do
    user = users(:test_user)
    stub_ai_response(AI_REPLY.slice(:professional_summary, :skills))

    run_job(user)

    generation = last_generation(user)
    assert_equal "completed", generation.status
    assert_equal [ [ "Technical Skills", [ "Ruby" ] ], [ "Technical Skills", [ "Rails" ] ] ],
                 generation.resume.skills.order(:id).map { |skill| [ skill.category, skill.skill_names ] }
    assert_equal [ { "category" => "Technical Skills", "names" => [ "Ruby", "Rails" ] } ],
                 generation.metadata["generated_data"]["skills"]
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
    user = users(:test_user)
    stub_ai_failure

    error = assert_raises(RuntimeError) { run_job(user) }
    assert_equal "API Error", error.message

    generation = last_generation(user)
    assert_equal "failed", generation.status
    assert_equal "API Error", generation.metadata["error"]
    assert generation.metadata["error_backtrace"].present?
    assert_nil generation.resume_id
  end

  test "another user's resume is refused and the run marked failed" do
    stub_ai_response(AI_REPLY)
    AiModel.expects(:complete).never

    assert_raises(ActiveRecord::RecordNotFound) { run_job(users(:test_user), resumes(:complete_resume).id) }
    assert_equal "failed", last_generation(users(:test_user)).status
  end

  test "new CV sends the golden prompts" do
    AiModel.expects(:complete)
           .with(system: golden("system_prompt.txt"), user: golden("user_prompt_new.txt"), temperature: 0.7, max_tokens: 15000)
           .returns(ai_message("Summary"))

    run_job(users(:test_user))
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
           .returns(ai_message("Summary"))

    run_job(users(:test_user), nil, { "temperature" => "0.2", "max_tokens" => "4000" })
  end
end
