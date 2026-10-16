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

  # Stub the whole chain: RubyLLM.chat checks Bedrock credentials, which CI doesn't have.
  def haiku
    llm = haiku_chain
    RubyLLM.stubs(:chat).returns(llm)
    llm
  end

  def haiku_chain
    llm = stub
    llm.stubs(:with_instructions).returns(llm)
    llm.stubs(:with_schema).returns(llm)
    llm
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
    haiku.expects(:ask).with { |text| !text.include?(EMAIL) }
         .returns(stub(parsed: { "next_step" => "skills", "scores" => { "skills" => 0.2 } }))

    assert_equal "skills", Coach::Judge.next_step(@draft)
  end

  test "a Jev error falls back to Haiku and is reported" do
    RubyLLM.config.stubs(:typesafe_api_key).returns("k")
    RubyLLM.expects(:judge).raises(RubyLLM::ServerError, "boom")
    Sentry.expects(:capture_exception).with(instance_of(RubyLLM::ServerError), tags: { pack: "coach" })
    haiku.stubs(:ask).returns(stub(parsed: { "next_step" => "languages", "scores" => { "languages" => 0.5 } }))

    result = Coach::Judge.call(@draft)

    assert_equal "languages", result["next_step"]
    assert_equal 0.5, result["scores"]["languages"]
  end

  test "next_step is always in SECTIONS and scores stay in 0..1" do
    RubyLLM.config.stubs(:typesafe_api_key).returns(nil)
    haiku.stubs(:ask).returns(stub(parsed: { "next_step" => "hobbies", "scores" => { "skills" => 7 } }))

    result = Coach::Judge.call(@draft)

    assert_includes Coach::Draft::SECTIONS, result["next_step"]
    assert_equal 1.0, result["scores"]["skills"]
  end

  test "a passed-in llm with judge? asks its judge, not RubyLLM" do
    fake = mock
    fake.stubs(:judge?).returns(true)
    fake.expects(:judge).with { |input, questions:|
      !input.include?(EMAIL) && questions.key?(:next_step)
    }.returns(judgment("skills", "skills" => 3.0))
    fake.expects(:fast_chat).never
    RubyLLM.expects(:judge).never
    RubyLLM.expects(:chat).never

    result = Coach::Judge.call(@draft, llm: fake)

    assert_equal "skills", result["next_step"]
    assert_equal 1.0, result["scores"]["skills"]
  end

  test "a passed-in llm without judge? answers through its fast chat" do
    fake = mock
    fake.stubs(:judge?).returns(false)
    fake.expects(:judge).never
    chain = haiku_chain
    chain.expects(:ask).returns(stub(parsed: { "next_step" => "education", "scores" => { "education" => 0.4 } }))
    fake.expects(:fast_chat).returns(chain)
    RubyLLM.expects(:chat).never

    assert_equal "education", Coach::Judge.next_step(@draft, llm: fake)
  end

  test "a passed-in llm whose judge raises falls back to its fast chat and is reported" do
    fake = mock
    fake.stubs(:judge?).returns(true)
    fake.expects(:judge).raises(RubyLLM::ServerError, "boom")
    Sentry.expects(:capture_exception).with(instance_of(RubyLLM::ServerError), tags: { pack: "coach" })
    chain = haiku_chain
    chain.stubs(:ask).returns(stub(parsed: { "next_step" => "languages", "scores" => { "languages" => 0.5 } }))
    fake.expects(:fast_chat).returns(chain)
    RubyLLM.expects(:chat).never

    scores = Coach::Judge.review(@draft, llm: fake)

    assert_equal 0.5, scores["languages"]
  end

  private

  def judgment(next_step, scores)
    answers = { next_step: stub(choice: next_step) }
    Coach::Draft::SECTIONS.each { |s| answers[s.to_sym] = stub(score: scores.fetch(s, 0.0)) }
    RubyLLM::Judgment.new(answers:, model: "jev-latest")
  end
end
