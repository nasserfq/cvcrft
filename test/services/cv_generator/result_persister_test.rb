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

  test "record! stores the summary, tokens and full structure and keeps prior metadata keys" do
    @persister.record!(RESULT, snapshot: nil)
    @generation.reload

    assert_equal "processing", @generation.status
    assert_equal "New summary", @generation.generated_content
    assert_equal 500, @generation.tokens_used
    assert_equal({
      "source" => "form",
      "ats_template" => "harvard_classic",
      "generated_data" => {
        "professional_summary" => "New summary",
        "work_experiences" => [ { "job_title" => "Lead", "company" => "PayCo" } ],
        "skills" => [ { "category" => "Tech", "names" => [ "Ruby" ] } ],
        "educations" => [], "certifications" => [], "languages" => []
      },
      "ats_optimization_notes" => "ats",
      "generation_notes" => "gen",
      "raw_response" => "{...}"
    }, @generation.metadata)
  end

  test "record! with a snapshot stores the snapshot sections under the new summary" do
    snapshot = { professional_summary: "Old", work_experiences: [ { company: "OldCo" } ], skills: [],
                 educations: [ { degree: "BSc" } ], certifications: [], languages: [] }

    @persister.record!(RESULT, snapshot: snapshot)

    assert_equal({
      "professional_summary" => "New summary",
      "work_experiences" => [ { "company" => "OldCo" } ], "skills" => [],
      "educations" => [ { "degree" => "BSc" } ], "certifications" => [], "languages" => []
    }, @generation.reload.metadata["generated_data"])
  end

  test "populate_sections! finds sections by their identifying keys and updates them" do
    resume = create_test_resume(@user)
    experience = resume.work_experiences.create!(company: "PayCo", job_title: "Lead", start_date: "2021-01", end_date: "2022-01")
    education = resume.educations.create!(degree: "BSc", institution: "KSU", start_date: "2010-09")
    certification = resume.certifications.create!(name: "AWS SA", organization: "Amazon", date: "2019-01")
    language = resume.languages.create!(language: "English", proficiency: "Basic")

    @persister.populate_sections!(resume, {
      work_experiences: [ { company: "PayCo", job_title: "Lead", start_date: "2021-01", end_date: "2023-01", responsibilities: "Led" },
                          { company: "NewCo", job_title: "CTO", start_date: "2023-02", responsibilities: [ "Ran" ] } ],
      educations: [ { degree: "BSc", institution: "KSU", start_date: "2010-09", end_date: "2014-06", gpa: "3.5" } ],
      certifications: [ { name: "AWS SA", organization: "Amazon", date: "2020-01" } ],
      languages: [ { language: "English", proficiency: "Fluent" }, { language: "Arabic", proficiency: "Native" } ]
    })

    assert_equal 2, resume.work_experiences.count
    assert_equal "2023-01", experience.reload.end_date
    assert_equal [ "Led" ].to_s, experience.responsibilities
    assert_equal [ "2014-06", "3.5" ], education.reload.values_at(:end_date, :gpa).map(&:to_s)
    assert_equal 1, resume.educations.count
    assert_equal "2020-01", certification.reload.date.to_s
    assert_equal "Fluent", language.reload.proficiency
    assert_equal 2, resume.languages.count
  end

  test "populate_sections! skips skills the resume already has, in either names format" do
    resume = create_test_resume(@user)
    resume.skills.create!(category: "Tech", name: "Ruby", skill_names: [ "Ruby" ])
    resume.skills.create!(category: "Tech", name: "Go", skill_names: [ "Go" ])

    assert_no_difference -> { resume.skills.count } do
      @persister.populate_sections!(resume, { skills: [ { category: "Tech", names: [ " Ruby ", nil, "" ] },
                                                        { category: "Tech", names: "Ruby, Go" } ] })
    end
  end

  test "populate_sections! creates a skill the resume does not have yet, one name per skill" do
    resume = create_test_resume(@user)

    @persister.populate_sections!(resume, { skills: [ { category: "Tech", names: [ "Elixir", " Go " ] } ] })

    assert_equal [ [ "Tech", "Elixir", [ "Elixir" ] ], [ "Tech", "Go", [ "Go" ] ] ],
                 resume.skills.order(:id).map { |skill| [ skill.category, skill.name, skill.skill_names ] }
  end

  test "populate_sections! reads the string-keyed sections JSON.parse gives" do
    resume = create_test_resume(@user)

    @persister.populate_sections!(resume, JSON.parse({
      work_experiences: [ { company: "PayCo", job_title: "Lead", start_date: "2021-01", responsibilities: [ "Led" ] } ],
      skills: [ { category: "Tech", names: "Ruby, Rails" } ],
      educations: [ { degree: "BSc", institution: "KSU", start_date: "2010-09", end_date: "2014-06" } ],
      certifications: [ { name: "AWS SA", organization: "Amazon", date: "2020-01" } ],
      languages: [ { language: "English", proficiency: "Fluent" } ]
    }.to_json))

    assert_equal [ [ "PayCo", "Lead", "2021-01" ] ], resume.work_experiences.pluck(:company, :job_title, :start_date)
    assert_equal [ [ "Ruby", [ "Ruby" ] ], [ "Rails", [ "Rails" ] ] ],
                 resume.skills.order(:id).map { |skill| [ skill.name, skill.skill_names ] }
    assert_equal [ [ "BSc", "KSU", "2010-09", "2014-06" ] ], resume.educations.pluck(:degree, :institution, :start_date, :end_date)
    assert_equal [ [ "AWS SA", "Amazon", "2020-01" ] ], resume.certifications.pluck(:name, :organization, :date)
    assert_equal [ [ "English", "Fluent" ] ], resume.languages.pluck(:language, :proficiency)
  end

  test "populate_sections! ignores missing and empty sections" do
    resume = create_test_resume(@user)

    assert_nothing_raised { @persister.populate_sections!(resume, { work_experiences: [], skills: nil }) }
    assert_equal 0, resume.work_experiences.count
  end
end
