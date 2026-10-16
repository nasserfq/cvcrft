module AtsStylePresets
  # Fictional, in-memory CV used to render the static template thumbnails in
  # public/ats_previews (see `bin/rails ats_previews:generate`). It duck-types
  # the Resume and WorkExperience methods the PDF renderers call, so nothing
  # touches the database.
  module AtsPreviewSample
    Resume = Struct.new(
      :id,
      :complete_name,
      :email,
      :phone_number,
      :city,
      :country,
      :professional_summary_english,
      :professional_summary,
      :work_experiences,
      keyword_init: true
    )

    WorkExperience = Struct.new(
      :job_title,
      :company,
      :start_date,
      :end_date,
      :is_current,
      :responsibilities,
      keyword_init: true
    )

    SUMMARY = "Operations and product leader with 12+ years of experience scaling digital services across " \
              "fintech and logistics. Led cross-functional teams of up to 40 people, launched platforms used by " \
              "over two million customers, and cut operating costs by 18% through process automation and " \
              "data-driven planning. Known for turning strategy into measurable delivery.".freeze

    def self.resume
      Resume.new(
        id: nil,
        complete_name: "Sara Al-Ahmad",
        email: "sara@example.com",
        phone_number: "+966 50 123 4567",
        city: "Riyadh",
        country: "Saudi Arabia",
        professional_summary_english: SUMMARY,
        professional_summary: SUMMARY,
        work_experiences: work_experiences
      )
    end

    # Dates use "YYYY-MM", the one format both the legacy and preset renderers
    # read; every renderer sorts the roles newest first itself.
    def self.work_experiences
      [
        WorkExperience.new(
          job_title: "Director of Product Operations",
          company: "Northwind Digital Services",
          start_date: "2021-03",
          end_date: nil,
          is_current: true,
          responsibilities: [
            "Lead a 40-person product operations organisation across three countries and five product lines.",
            "Launched a self-service payments platform that reached 2.1M active customers in 18 months.",
            "Introduced quarterly OKR planning, raising on-time roadmap delivery from 61% to 89%.",
            "Reduced vendor and cloud spend by 18% through contract consolidation and usage reviews."
          ]
        ),
        WorkExperience.new(
          job_title: "Senior Operations Manager",
          company: "Bluepeak Logistics",
          start_date: "2017-01",
          end_date: "2021-02",
          is_current: false,
          responsibilities: [
            "Managed last-mile delivery operations for 14 cities with a 1,200-driver network.",
            "Built a demand forecasting model that lowered missed delivery windows by 27%.",
            "Rolled out a warehouse management system across 6 sites with zero service downtime."
          ]
        ),
        WorkExperience.new(
          job_title: "Business Analyst",
          company: "Crescent Consulting Group",
          start_date: "2013-07",
          end_date: "2016-12",
          is_current: false,
          responsibilities: [
            "Delivered process redesign projects for banking and retail clients in the GCC region.",
            "Produced executive dashboards that became the standard reporting pack for 9 clients."
          ]
        )
      ].reverse
    end

    def self.data
      {
        professional_summary: SUMMARY,
        educations: [
          {
            degree: "MBA, Strategy and Operations",
            institution: "King Saud University",
            start_date: "2014",
            end_date: "2016"
          },
          {
            degree: "BSc Industrial Engineering",
            institution: "King Fahd University of Petroleum and Minerals",
            start_date: "2009",
            end_date: "2013"
          }
        ],
        skills: [
          { category: "Leadership", details: "Team building, Stakeholder management, Change management, Coaching" },
          { category: "Operations", details: "Process improvement, Lean Six Sigma, Supply chain, Vendor management" },
          { category: "Product", details: "Roadmapping, OKRs, Agile delivery, Customer research" },
          { category: "Tools", details: "SQL, Power BI, Jira, Excel modelling, SAP" }
        ],
        certifications: [
          { name: "Project Management Professional (PMP)", organization: "PMI", date: "2019" },
          { name: "Lean Six Sigma Black Belt", organization: "ASQ", date: "2018" },
          { name: "Certified Scrum Product Owner", organization: "Scrum Alliance", date: "2021" }
        ],
        languages: [
          { language: "Arabic", proficiency: "Native" },
          { language: "English", proficiency: "Fluent" },
          { language: "French", proficiency: "Intermediate" }
        ]
      }
    end
  end
end
