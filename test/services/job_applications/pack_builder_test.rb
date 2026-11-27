require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::PackBuilderTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  QUESTIONS = [
    { "id" => "first_name", "label" => "First Name", "type" => "text", "required" => true },
    { "id" => "resume", "label" => "Resume/CV", "type" => "file", "required" => true },
    { "id" => "cover", "label" => "Cover Letter", "type" => "file", "required" => false },
    { "id" => "hear", "label" => "How did you hear about us?", "type" => "select", "options" => %w[LinkedIn Friend], "required" => true },
    { "id" => "why", "label" => "Why do you want to work here?", "type" => "textarea", "required" => true },
    { "id" => "salary", "label" => "Expected salary", "type" => "text", "required" => true },
    { "id" => "gender", "label" => "Gender", "type" => "select", "options" => %w[Female Male], "required" => false, "section" => "eeo" }
  ].freeze

  setup do
    @user = users(:one)
    @resume = finished_resume(@user, professional_summary_english: "Product manager.")
    @profile = create_profile(@user)
    @application = create_application(@user, status: "preparing", channel: "browser")
    submitter = Class.new { def self.questions(_posting) = QUESTIONS }
    JobApplications::Submitters.stubs(:for).returns(submitter)
  end

  def reply(text) = Struct.new(:content).new(text)

  def stub_ai(answers: [])
    AiModel.stubs(:complete).with { |args| args[:system] == JobApplications::TailoredSummary::SYSTEM_PROMPT }
      .returns(reply("Product manager who ships payments."))
    AiModel.stubs(:complete).with { |args| args[:system] == JobApplications::Answerer::SYSTEM_PROMPT }
      .returns(reply({ "answers" => answers }.to_json))
  end

  test "writes the cv_pdf, answers what it can and lists the rest as missing" do
    stub_ai(answers: [ { "id" => "why", "value" => "I like payments." } ])

    pack = JobApplications::PackBuilder.new(@application).call

    pdf = @application.reload.cv_pdf
    assert_equal "application/pdf", pdf.content_type
    assert pdf.data.start_with?("%PDF")
    assert_equal "Product manager who ships payments.", pack[:summary]
    assert_equal({ "first_name" => "Sara", "resume" => "cv_pdf", "why" => "I like payments." }, pack[:answers])
    assert_equal %w[salary hear], pack[:missing]
    assert_nil pack[:cover_letter]
    assert_equal QUESTIONS.size, pack[:questions].size
  end

  test "bumps the packs counter once" do
    stub_ai

    assert_difference -> { JobApplications::AiUsage.for(@user).packs }, 1 do
      JobApplications::PackBuilder.new(@application).call
    end
  end

  test "uses the profile's saved answers by label" do
    stub_ai
    @profile.remember_answers!("How did you hear about us?" => "Friend", "Why do you want to work here?" => "Mission.")

    pack = JobApplications::PackBuilder.new(@application).call

    assert_equal "Friend", pack[:answers]["hear"]
    assert_equal "Mission.", pack[:answers]["why"]
    assert_equal %w[salary], pack[:missing]
  end

  test "a required cover letter is written once from CV facts" do
    stub_ai
    AiModel.stubs(:complete).with { |args| args[:system] == JobApplications::CoverLetter::SYSTEM_PROMPT }
      .returns(reply("Dear hiring team, I build payment products."))
    questions = QUESTIONS.map { |q| q["id"] == "cover" ? q.merge("required" => true) : q }
    JobApplications::Submitters.stubs(:for).returns(Class.new { define_singleton_method(:questions) { |_posting| questions } })

    pack = JobApplications::PackBuilder.new(@application).call

    assert_equal "Dear hiring team, I build payment products.", pack[:cover_letter]
    assert_equal pack[:cover_letter], pack[:answers]["cover"]
  end

  test "an email application has no questions" do
    @application.update!(channel: "email")
    AiModel.stubs(:complete).returns(reply("Product manager who ships payments."))

    pack = JobApplications::PackBuilder.new(@application).call

    assert_empty pack[:questions]
    assert_empty pack[:missing]
    assert @application.reload.cv_pdf
  end
end
