require "test_helper"

class CvGenerator::ResultPersisterTest < ActiveSupport::TestCase
  RESULT = {
    professional_summary: "New summary",
    work_experiences: [ { job_title: "Lead", company: "PayCo" } ],
    skills: [ { category: "Tech", names: [ "Ruby" ] } ],
    educations: [], certifications: [], languages: [],
    ats_optimization_notes: "ats", generation_notes: "gen",
    tokens_used: 500, raw_response: "{...}"
  }.freeze

  setup do
    stub_pdf_generation
    @user = users(:test_user)
    @generation = create_test_cv_generation(@user, metadata: { "source" => "form", "ats_template" => "harvard_classic" })
    @persister = CvGenerator::ResultPersister.new(@generation)
  end

  SNAPSHOT = { professional_summary: "Old", work_experiences: [ { company: "OldCo" } ], skills: [],
               educations: [ { degree: "BSc" } ], certifications: [], languages: [] }.freeze

  test "record! stores the summary, tokens and full structure and keeps prior metadata keys" do
    @persister.record!(RESULT, snapshot: SNAPSHOT)
    @generation.reload

    assert_equal "processing", @generation.status
    assert_equal "New summary", @generation.generated_content
    assert_equal 500, @generation.tokens_used
    assert_equal({
      "source" => "form",
      "ats_template" => "harvard_classic",
      "generated_data" => {
        "professional_summary" => "New summary",
        "work_experiences" => [ { "company" => "OldCo" } ], "skills" => [],
        "educations" => [ { "degree" => "BSc" } ], "certifications" => [], "languages" => []
      },
      "ats_optimization_notes" => "ats",
      "generation_notes" => "gen",
      "raw_response" => "{...}"
    }, @generation.metadata)
  end

  test "record! takes only the summary from the AI result; the AI's other sections are ignored" do
    @persister.record!(RESULT, snapshot: SNAPSHOT)

    data = @generation.reload.metadata["generated_data"]
    assert_equal "New summary", data["professional_summary"]
    assert_equal JSON.parse(SNAPSHOT.except(:professional_summary).to_json), data.except("professional_summary")
  end

  test "record! without a snapshot refuses and writes nothing" do
    assert_raises(ArgumentError) { @persister.record!(RESULT, snapshot: nil) }
    assert_nil @generation.reload.generated_content
    assert_nil @generation.metadata["generated_data"]
  end
end
