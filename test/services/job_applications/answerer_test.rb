require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::AnswererTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  setup do
    @user = users(:one)
    @profile = create_profile(@user)
    @application = create_application(@user, status: "preparing")
  end

  def reply(answers)
    Struct.new(:content).new({ "answers" => answers }.to_json)
  end

  def q(id, label, type: "text", options: [], required: true, section: "main")
    { "id" => id, "label" => label, "type" => type, "options" => options, "required" => required, "section" => section }
  end

  def answerer
    JobApplications::Answerer.new(@application, profile: @profile, facts: '{"skills":["Roadmaps"]}')
  end

  test "sensitive, EEO and file questions never reach the AI" do
    questions = [
      q("why", "Why do you want to join us?", type: "textarea"),
      q("gender", "What is your gender?", type: "select", options: %w[Female Male]),
      q("felony", "Have you ever been convicted of a felony?", type: "radio", options: %w[Yes No]),
      q("eeo", "Race / ethnicity", type: "select", options: %w[A B], section: "eeo"),
      q("terms", "I agree to the privacy policy", type: "checkbox", options: [ "I agree" ]),
      q("salary", "Expected salary"),
      q("doc", "Portfolio", type: "file")
    ]
    AiModel.expects(:complete).once.with do |args|
      prompt = args[:user]
      prompt.include?("Why do you want to join us?") && prompt.include?("Roadmaps") &&
        [ "gender", "felony", "Race", "privacy policy", "salary", "Portfolio" ].none? { |text| prompt.include?(text) }
    end.returns(reply([ { "id" => "why", "value" => "I build products." } ]))

    result = answerer.call(questions)

    assert_equal({ "why" => "I build products." }, result[:answers])
    assert_equal %w[gender felony eeo terms salary doc], result[:missing]
  end

  test "options are enforced in Ruby" do
    questions = [
      q("level", "Seniority", type: "select", options: %w[Junior Senior]),
      q("tools", "Tools you use", type: "checkbox", options: %w[Jira Figma]),
      q("years", "Years of experience", type: "number")
    ]
    AiModel.stubs(:complete).returns(reply([
      { "id" => "level", "value" => "Principal" },
      { "id" => "tools", "value" => %w[Jira Notion] },
      { "id" => "years", "value" => "about five" }
    ]))

    result = answerer.call(questions)

    assert_equal({ "tools" => [ "Jira" ] }, result[:answers])
    assert_equal %w[level years], result[:missing]
  end

  test "bad JSON leaves everything missing" do
    AiModel.stubs(:complete).returns(Struct.new(:content).new("not json"))

    result = answerer.call([ q("a", "Why us?"), q("b", "Favourite project?") ])

    assert_empty result[:answers]
    assert_equal %w[a b], result[:missing]
  end

  test "a required unknown is missing, an optional unknown is blank" do
    AiModel.stubs(:complete).returns(reply([ { "id" => "a", "value" => nil }, { "id" => "b", "value" => nil } ]))

    result = answerer.call([ q("a", "Why us?"), q("b", "Anything else?", required: false) ])

    assert_empty result[:answers]
    assert_equal %w[a], result[:missing]
  end

  test "an open breaker raises so the job retries" do
    AiModel.stubs(:complete).raises(AiCircuit::OpenError.new("open"))

    assert_raises(AiCircuit::OpenError) { answerer.call([ q("a", "Why us?") ]) }
  end

  test "no AI call when nothing is askable" do
    AiModel.expects(:complete).never

    assert_equal({ answers: {}, missing: [ "g" ] }, answerer.call([ q("g", "Gender") ]))
  end
end
