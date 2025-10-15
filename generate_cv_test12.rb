#!/usr/bin/env ruby
require 'prawn'
require 'date'
require 'ostruct'

# Create test data to match the image
test_data = {
  professional_summary: "Adept Project Manager with a Bachelor's in Computer Science and PMP certification, specializing in IT and AI projects. Experienced in project planning, budgeting, and timeline management, ensuring successful implementations and stakeholder alignment. Skilled in utilizing tools like JIRA and agile methodologies to lead cross-functional teams and mitigate risks effectively.",
  educations: [
    {
      degree: "Diploma in Data Science bootcamp",
      institution: "SDA",
      start_date: "2020-08",
      end_date: "2020-12"
    },
    {
      degree: "Bachelor's Degree in Computer Science",
      institution: "Avila University",
      start_date: "2014-08",
      end_date: "2019-08",
      gpa: "(GPA: 2.95/4)"
    }
  ],
  work_experiences: [
    {
      job_title: "Project Manager",
      company: "Digital Future",
      start_date: "2025-09",
      end_date: "Present",
      responsibilities: [
        "Project Manager at Digital Future"
      ]
    },
    {
      job_title: "AI Product Manager",
      company: "Masterly company for services and information technology",
      start_date: "2025-07",
      end_date: "2025-08",
      responsibilities: [
        "Developing AI agents with a React frontend and Supabase backend, alongside responsibilities in business analysis and product management"
      ]
    },
    {
      job_title: "Technical Product Manager",
      company: "Masterly Motion Media",
      start_date: "2024-05",
      end_date: "2025-04",
      responsibilities: [
        "Driving innovation through the development of AI-powered in-house web applications while strategically overseeing the execution of external web and mobile projects",
        "Skilled in creating innovative solutions that align seamlessly with business objectives and elevate user experience",
        "I personally build and integrate AI capabilities within Ruby on Rails applications, enhancing functionality and driving innovation in our product offerings"
      ]
    },
    {
      job_title: "Software Engineer and Founder",
      company: "Aqarate.AI",
      start_date: "2024-02",
      end_date: "Present",
      responsibilities: [
        "Develop it entirely using Ruby on Rails, PostgreSQL, and OpenAI",
        "Its target audience comprises B2B customers in the real estate industry",
        "The platform is primarily designed for generating real estate marketing content through AI"
      ]
    },
    {
      job_title: "Founder and software engineer",
      company: "Shukran App",
      start_date: "2021-01",
      end_date: "2023-12",
      responsibilities: [
        "Developed Shukran web app side project using Ruby on Rails, PostgreSQL, and Tailwind CSS",
        "Integrated the app Moyasar Payment Gateway API",
        "Utilized a proactive approach to customer reach"
      ]
    },
    {
      job_title: "Project Manager",
      company: "National center for Privatization",
      start_date: "2022-12",
      end_date: "2023-06",
      responsibilities: [
        "Work on various IT projects, contributing to the development of project plans, timelines, and budgets for successful implementation",
        "Develop and deploy technological solutions to support project goals, ensuring alignment with project plans and timelines"
      ]
    },
    {
      job_title: "System Engineer",
      company: "Shomoos Tech company",
      start_date: "2021-01",
      end_date: "2021-12",
      responsibilities: [
        "Spearheaded Power BI data modeling, streamlining company-wide reporting",
        "Centralized sales, inventory, and customer data using Power Query",
        "Cleansed datasets in Power Query, ensuring accurate business insights",
        "Built robust Power BI data models, optimizing dashboard performance and cross-departmental analysis",
        "Managed and maintained Microsoft SQL Server, ensuring optimal performance, reliability, and security"
      ]
    }
  ],
  skills: [
    {
      category: "Project Management Tools",
      details: "Microsoft Project, JIRA, Confluence, Agile, Waterfall"
    },
    {
      category: "Business and Product Alignment",
      details: "Budgeting, Scope Management, Risk Management, Stakeholder Communication"
    },
    {
      category: "Technical Implementation",
      details: "Power BI, SQL Server, Ruby on Rails, PostgreSQL, React, Supabase"
    },
    {
      category: "AI and Data Integration",
      details: "OpenAI, Data Modeling, Power Query, AI Agents"
    },
    {
      category: "Soft Skills",
      details: "Team Leadership, Problem-Solving, Communication, Time Management"
    }
  ],
  certifications: [
    {
      name: "Product Management in KSA",
      organization: "Maharah",
      status: "in progress",
      date: "2025-09"
    },
    {
      name: "PMP®",
      organization: "PMI",
      date: "2025-08"
    },
    {
      name: "Azure AI Engineer Associate",
      organization: "Microsoft",
      status: "in progress",
      date: "2025-08"
    },
    {
      name: "AI for product management",
      organization: "Portfolio",
      date: "2025-08"
    },
    {
      name: "Data Science",
      organization: "SDA",
      date: "2020-12"
    }
  ],
  languages: [
    {
      language: "English",
      proficiency: "fluent"
    },
    {
      language: "Arabic",
      proficiency: "native"
    }
  ]
}

# Create mock resume data
resume = OpenStruct.new(
  complete_name: "Nasser Alqahtani",
  email: "non1993@protonmail.com",
  phone_number: "+966505570007",
  city: "Riyadh",
  country: "Saudi Arabia"
)

def generate_section_title(pdf, title)
  pdf.move_down 10
  pdf.fill_color "000080" # Navy blue color
  pdf.text title, size: 13, style: :bold
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.fill_color "000000" # Reset to black
  pdf.stroke_color "000080" # Keep blue line
  pdf.move_down 8
end

# Helper method to format skills text
def format_skills_text(details)
  # Split the skills string into individual items
  skills = details.split(", ")
  formatted_items = []

  # Format each skill as regular text (not bold)
  skills.each_with_index do |skill, index|
    formatted_items << { text: skill, size: 10 }
    formatted_items << { text: ", ", size: 10 } if index < skills.length - 1
  end

  formatted_items
end

# Generate the PDF
def generate_test_pdf(resume, data)
  pdf = Prawn::Document.new(
    page_size: "A4",
    margin: [ 40, 40, 40, 40 ],
    page_layout: :portrait
  )

  pdf.font "Helvetica"

  # Name at the top
  pdf.text resume.complete_name.to_s.strip, size: 20, style: :bold, align: :center
  pdf.move_down 4

  # Contact info on one line
  contact_text = "#{resume.email} | #{resume.phone_number} | #{resume.city}, #{resume.country}"
  pdf.text contact_text, size: 10, align: :center

  # Blue line under contact info
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.move_down 15

  # Professional Summary
  generate_section_title(pdf, "Professional Summary")
  pdf.text data[:professional_summary].to_s.strip, size: 10, align: :justify
  pdf.move_down 10

  # Education
  generate_section_title(pdf, "Education")
  data[:educations].each do |education|
    # Keep degree titles bold
    pdf.text education[:degree].to_s.strip, size: 11, style: :bold
    pdf.move_up 13
    pdf.text "#{education[:start_date]} - #{education[:end_date]}", align: :right, size: 10
    pdf.text education[:institution], size: 10
    pdf.text education[:gpa].to_s, size: 10 if education[:gpa]
    pdf.move_down 5
  end

  # Work Experience
  generate_section_title(pdf, "Work Experience")
  data[:work_experiences].each do |exp|
    # Keep job titles bold
    pdf.text exp[:job_title], size: 11, style: :bold
    pdf.move_up 13
    pdf.text "#{exp[:start_date]} - #{exp[:end_date].to_s.capitalize}", align: :right, size: 10
    pdf.text exp[:company], size: 10

    Array(exp[:responsibilities]).each do |resp|
      pdf.text "• #{resp}", size: 10, leading: 2
    end
    pdf.move_down 8
  end

  # Skills
  generate_section_title(pdf, "Skills")
  data[:skills].each do |skill|
    # Category in bold with colon
    pdf.text "#{skill[:category]}:", size: 10, style: :bold
    # Skills in regular text
    pdf.text skill[:details], size: 10
    pdf.move_down 2
  end

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    # Use formatted_text to mix bold and regular styles
    pdf.formatted_text [
      { text: cert[:name], size: 10, style: :bold }  # Certificate name in bold
    ]

    # Add status and organization in regular text if they exist
    status_and_org = ""
    status_and_org += " (#{cert[:status]})" if cert[:status]
    status_and_org += " (#{cert[:organization]})" if cert[:organization]

    if !status_and_org.empty?
      pdf.move_up 11.5  # Adjust position to append to the same line
      pdf.text status_and_org, size: 10
    end

    # Add date on the right
    pdf.move_up 11.5
    pdf.text cert[:date], align: :right, size: 10
    pdf.move_down 2
  end

  # Languages
  generate_section_title(pdf, "Languages")
  data[:languages].each do |lang|
    # Make language name bold
    pdf.text lang[:language], size: 10, style: :bold
    pdf.move_up 12
    pdf.text lang[:proficiency], align: :right, size: 10
    pdf.move_down 2
  end

  pdf.render
end

# Generate and save the test PDF
begin
  puts "Generating CV PDF..."
  pdf_content = generate_test_pdf(resume, test_data)
  output_path = File.join(Dir.pwd, "test12.pdf")
  File.write(output_path, pdf_content)
  puts "✓ Successfully generated CV PDF!"
  puts "PDF saved at: #{output_path}"
rescue => e
  puts "Error generating CV:"
  puts e.message
  puts e.backtrace
end
