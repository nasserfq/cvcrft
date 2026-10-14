require "test_helper"

class Coach::JudgeTest < ActiveSupport::TestCase
  NAME = "Sara Ali"
  EMAIL = "sara@example.com"
  PHONE = "+966500000000"

  setup do
    @draft = {
      "complete_name" => NAME, "email" => EMAIL, "phone_number" => PHONE, "city" => "Riyadh", "country" => "Saudi Arabia",
      "professional_summary" => "Cashier with five years in retail.",
      "work_experience" => [ { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01", "responsibilities" => [ "Served customers" ] } ]
    }
  end

  test "Jev gets section text without the header's values" do
    RubyLLM.config.stubs(:typesafe_api_key).returns("k")
    RubyLLM.expects(:judge).with { |input, **opts|
      [ NAME, EMAIL, PHONE, "Riyadh", "Saudi Arabia" ].none? { |v| input.include?(v) } &&
        input.include?("Cashier with five years") && input.include?("Panda") &&
        opts[:model] == "jev-latest" && opts[:provider] == :typesafe
    }.returns(judgment("education", "work_experience" => 2.0))
    RubyLLM.expects(:chat).never

    result = Coach::Judge.call(@draft)

    assert_equal "education", result["next_step"]
    assert_in_delta 2.0 / 3, result["scores"]["work_experience"]
    assert_equal Coach::Draft::SECTIONS.sort, result["scores"].keys.sort
  end

  test "without a key Haiku answers and Jev is never called" do
    RubyLLM.config.stubs(:typesafe_api_key).returns(nil)
    RubyLLM.expects(:judge).never
    RubyLLM::Chat.any_instance.expects(:ask).with { |text| !text.include?(EMAIL) }
                 .returns(stub(parsed: { "next_step" => "skills", "scores" => { "skills" => 0.2 } }))

    assert_equal "skills", Coach::Judge.next_step(@draft)
  end

  test "a Jev error falls back to Haiku and is reported" do
    RubyLLM.config.stubs(:typesafe_api_key).returns("k")
    RubyLLM.expects(:judge).raises(RubyLLM::ServerError, "boom")
    Sentry.expects(:capture_exception).with(instance_of(RubyLLM::ServerError), tags: { pack: "coach" })
    RubyLLM::Chat.any_instance.stubs(:ask).returns(stub(parsed: { "next_step" => "languages", "scores" => { "languages" => 0.5 } }))

    result = Coach::Judge.call(@draft)

    assert_equal "languages", result["next_step"]
    assert_equal 0.5, result["scores"]["languages"]
  end

  test "next_step is always in SECTIONS and scores stay in 0..1" do
    RubyLLM.config.stubs(:typesafe_api_key).returns(nil)
    RubyLLM::Chat.any_instance.stubs(:ask).returns(stub(parsed: { "next_step" => "hobbies", "scores" => { "skills" => 7 } }))

    result = Coach::Judge.call(@draft)

    assert_includes Coach::Draft::SECTIONS, result["next_step"]
    assert_equal 1.0, result["scores"]["skills"]
  end

  private

  def judgment(next_step, scores)
    answers = { next_step: stub(choice: next_step) }
    Coach::Draft::SECTIONS.each { |s| answers[s.to_sym] = stub(score: scores.fetch(s, 0.0)) }
    RubyLLM::Judgment.new(answers:, model: "jev-latest")
  end
end
