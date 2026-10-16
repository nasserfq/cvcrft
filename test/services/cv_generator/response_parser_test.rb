require "test_helper"

class CvGenerator::ResponseParserTest < ActiveSupport::TestCase
  REPLY = {
    professional_summary: "New summary",
    work_experiences: [ { job_title: "Lead", company: "PayCo" } ],
    skills: [ { category: "Tech", names: [ "Ruby" ] } ],
    ats_optimization_notes: "ats", generation_notes: "gen"
  }.freeze

  SNAPSHOT = {
    professional_summary: "Old summary",
    work_experiences: [ { job_title: "Engineer", company: "OldCo" } ],
    skills: [ { category: "technical", names: [ "Go" ], details: "Go" } ],
    educations: [], certifications: [], languages: [ { language: "Arabic", proficiency: "Native" } ]
  }.freeze

  def ai_message(content, input: 300, output: 200)
    Struct.new(:content, :tokens).new(content, Struct.new(:input, :output).new(input, output))
  end

  test "new CV takes every section from the reply" do
    result = CvGenerator::ResponseParser.new(snapshot: nil).call(ai_message(REPLY.to_json))

    assert_equal({
      professional_summary: "New summary",
      work_experiences: [ { "job_title" => "Lead", "company" => "PayCo" } ],
      skills: [ { "category" => "Tech", "names" => [ "Ruby" ] } ],
      educations: [], certifications: [], languages: [],
      ats_optimization_notes: "ats", generation_notes: "gen",
      tokens_used: 500, raw_response: REPLY.to_json
    }, result)
  end

  test "existing resume keeps the snapshot sections and takes only the summary" do
    result = CvGenerator::ResponseParser.new(snapshot: SNAPSHOT).call(ai_message(REPLY.to_json))

    assert_equal({
      professional_summary: "New summary",
      work_experiences: SNAPSHOT[:work_experiences],
      skills: SNAPSHOT[:skills],
      educations: [], certifications: [],
      languages: SNAPSHOT[:languages],
      ats_optimization_notes: "Preserved all existing resume data",
      generation_notes: "Updated only professional summary while preserving all existing data",
      tokens_used: 500, raw_response: REPLY.to_json,
      using_existing_data: true
    }, result)
  end

  test "a fenced reply is unwrapped before parsing" do
    result = CvGenerator::ResponseParser.new(snapshot: nil).call(ai_message("Here you go:\n```json\n#{REPLY.to_json}\n```\nThanks"))

    assert_equal "New summary", result[:professional_summary]
    assert_equal REPLY.to_json, result[:raw_response]
  end

  test "a non-JSON reply becomes the summary with empty sections" do
    result = CvGenerator::ResponseParser.new(snapshot: SNAPSHOT).call(ai_message("Just prose"))

    assert_equal({
      professional_summary: "Just prose",
      work_experiences: [], skills: [], educations: [], certifications: [], languages: [],
      ats_optimization_notes: "Response was not in expected JSON format",
      generation_notes: "Response was not in expected JSON format",
      tokens_used: 500, raw_response: "Just prose"
    }, result)
  end

  test "tokens_used comes from AiModel.token_count" do
    reply = ai_message(REPLY.to_json)
    AiModel.expects(:token_count).with(reply).returns(1234)

    assert_equal 1234, CvGenerator::ResponseParser.new(snapshot: nil).call(reply)[:tokens_used]
  end
end
