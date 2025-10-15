#!/usr/bin/env ruby
require 'logger'
require 'ostruct'
require 'json'
require 'base64'
require 'prawn'
require 'date'

class Object
  def present?
    !blank?
  end

  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

# Mock minimal Rails environment
module Rails
  class << self
    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def application
      OpenStruct.new(
        credentials: OpenStruct.new(
          azure: { openai_api_key: ENV['AZURE_OPENAI_API_KEY'] }
        )
      )
    end
  end
end

# Test data structure (similar to generate_cv_test19.rb)
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
        "Leading multiple cross-functional teams in developing AI-powered solutions",
        "Managing project budgets exceeding $1M with consistent on-time delivery",
        "Implementing agile methodologies resulting in 30% faster project completion",
        "Coordinating with stakeholders to align project goals with business objectives"
      ]
    },
    {
      job_title: "AI Product Manager",
      company: "Masterly company for services and information technology",
      start_date: "2025-07",
      end_date: "2025-08",
      responsibilities: [
        "Developing AI agents with a React frontend and Supabase backend",
        "Leading business analysis and product management initiatives",
        "Implementing machine learning models for improved user experience",
        "Collaborating with data scientists to optimize AI model performance"
      ]
    },
    {
      job_title: "Technical Product Manager",
      company: "Masterly Motion Media",
      start_date: "2024-05",
      end_date: "2025-04",
      responsibilities: [
        "Driving innovation through the development of AI-powered in-house web applications",
        "Strategically overseeing the execution of external web and mobile projects",
        "Creating innovative solutions that align seamlessly with business objectives",
        "Building and integrating AI capabilities within Ruby on Rails applications",
        "Managing a team of 8 developers and achieving 40% improvement in delivery time"
      ]
    },
    {
      job_title: "Software Engineer and Founder",
      company: "Aqarate.AI",
      start_date: "2024-02",
      end_date: "Present",
      responsibilities: [
        "Developed complete platform using Ruby on Rails, PostgreSQL, and OpenAI",
        "Architected scalable B2B solution for real estate industry",
        "Implemented AI-powered content generation system for marketing materials",
        "Achieved 45% reduction in content creation time for clients",
        "Managed cloud infrastructure ensuring 99.9% uptime"
      ]
    },
    {
      job_title: "Founder and Software Engineer",
      company: "Shukran App",
      start_date: "2021-01",
      end_date: "2023-12",
      responsibilities: [
        "Developed full-stack web application using Ruby on Rails, PostgreSQL, and Tailwind CSS",
        "Integrated secure payment processing through Moyasar Payment Gateway API",
        "Implemented responsive design principles for optimal user experience",
        "Achieved 40% month-over-month user growth through strategic improvements",
        "Managed all aspects of development, deployment, and maintenance"
      ]
    },
    {
      job_title: "Project Manager",
      company: "National Center for Privatization",
      start_date: "2022-12",
      end_date: "2023-06",
      responsibilities: [
        "Managed multiple IT projects with combined budgets exceeding $5M",
        "Developed comprehensive project plans, timelines, and budgets",
        "Led successful implementation of enterprise-level technological solutions",
        "Coordinated with multiple departments to ensure project alignment",
        "Achieved 25% reduction in project delivery timeframes"
      ]
    },
    {
      job_title: "System Engineer",
      company: "Shomoos Tech Company",
      start_date: "2021-01",
      end_date: "2021-12",
      responsibilities: [
        "Spearheaded Power BI data modeling, streamlining company-wide reporting",
        "Centralized sales, inventory, and customer data using Power Query",
        "Cleansed and optimized datasets ensuring 99% data accuracy",
        "Built robust Power BI data models improving dashboard performance by 60%",
        "Managed Microsoft SQL Server infrastructure for 200+ users"
      ]
    },
    {
      job_title: "Junior Software Developer",
      company: "Tech Solutions Arabia",
      start_date: "2020-01",
      end_date: "2020-12",
      responsibilities: [
        "Developed and maintained web applications using PHP and MySQL",
        "Collaborated with senior developers on large-scale projects",
        "Implemented responsive design principles using Bootstrap",
        "Participated in code reviews and quality assurance processes",
        "Reduced bug resolution time by 35% through improved testing procedures"
      ]
    }
  ],
  skills: [
    {
      category: "Project Management Tools",
      details: "Microsoft Project, JIRA, Confluence, Trello, Azure DevOps, Asana, Monday.com"
    },
    {
      category: "Project Methodologies",
      details: "Agile, Scrum, Kanban, Waterfall, Hybrid, SAFe, Prince2"
    },
    {
      category: "Business and Product Alignment",
      details: "Strategic Planning, Budgeting, Risk Management, Stakeholder Management, Resource Allocation"
    },
    {
      category: "Technical Skills",
      details: "Ruby on Rails, PostgreSQL, React, Node.js, Power BI, SQL Server, Git, Docker"
    },
    {
      category: "AI and Data",
      details: "OpenAI API, Machine Learning, Data Modeling, Power Query, Azure AI, Data Analytics"
    },
    {
      category: "Leadership",
      details: "Team Management, Mentoring, Cross-functional Leadership, Conflict Resolution"
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

def generate_section_title(pdf, title)
  pdf.move_down 10
  pdf.fill_color "000080" # Navy blue color
  pdf.text title, size: 13, style: :bold
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.fill_color "000000" # Reset to black
  pdf.stroke_color "000080" # Keep blue line
  pdf.move_down 12  # Increased from 8 to 12 for better spacing
end

def generate_test_pdf(resume_data, data)
  pdf = Prawn::Document.new(
    page_size: "A4",
    margin: [ 40, 40, 40, 40 ],
    page_layout: :portrait
  )

  pdf.font "Helvetica"

  # Name at the top
  pdf.text resume_data.complete_name.to_s.strip, size: 20, style: :bold, align: :center
  pdf.move_down 4

  # Contact info on one line
  contact_text = "#{resume_data.email} | #{resume_data.phone_number} | #{resume_data.city}, #{resume_data.country}"
  pdf.text contact_text, size: 10, align: :center

  # Blue line under contact info
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.move_down 15

  # Professional Summary
  if data[:professional_summary].present?
    generate_section_title(pdf, "Professional Summary")
    pdf.text data[:professional_summary].to_s.strip, size: 10, align: :justify
    pdf.move_down 10
  end

  # Education
  if data[:educations].present?
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
  end

  # Work Experience
  if data[:work_experiences].present?
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
  end

  # Skills
  if data[:skills].present?
    generate_section_title(pdf, "Skills")
    data[:skills].each do |skill|
      # Category in bold with colon
      pdf.text "#{skill[:category]}:", size: 10, style: :bold
      # Skills in regular text
      pdf.text skill[:details], size: 10
      pdf.move_down 2
    end
  end

  # Certificates
  if data[:certifications].present?
    generate_section_title(pdf, "Certificates")
    pdf.move_down 5  # Add extra space after the section title
    data[:certifications].each do |cert|
      # Store current vertical position
      y_position = pdf.cursor

      # Draw the certificate name in bold
      pdf.font("Helvetica", style: :bold) do
        pdf.draw_text cert[:name], at: [ 0, y_position ], size: 10
      end

      # Calculate where the bold text ends
      name_width = pdf.width_of(cert[:name], style: :bold, size: 10)

      # Add status and organization info in regular text
      info_parts = []
      info_parts << "(#{cert[:status]})" if cert[:status]
      info_parts << "(#{cert[:organization]})" if cert[:organization]

      if info_parts.any?
        pdf.font("Helvetica", style: :normal) do
          pdf.draw_text " #{info_parts.join(' ')}",
            at: [ name_width, y_position ],
            size: 10
        end
      end

      # Add date on the right
      pdf.font("Helvetica", style: :normal) do
        pdf.draw_text cert[:date],
          at: [ 500 - pdf.width_of(cert[:date], size: 10), y_position ],
          size: 10
      end

      # Move down for next item
      pdf.move_down 15
    end
  end

  # Languages
  if data[:languages].present?
    generate_section_title(pdf, "Languages")
    data[:languages].each do |lang|
      # Make language name bold
      pdf.text lang[:language], size: 10, style: :bold
      pdf.move_up 12
      pdf.text lang[:proficiency], align: :right, size: 10
      pdf.move_down 2
    end
  end

  pdf.render
end

# Generate and save the test PDF
begin
  puts "Generating test CV PDF..."
  resume_data = OpenStruct.new(
    complete_name: "Nasser Alqahtani",
    email: "non1993@protonmail.com",
    phone_number: "+966505570007",
    city: "Riyadh",
    country: "Saudi Arabia"
  )

  pdf_content = generate_test_pdf(resume_data, test_data)
  output_path = File.join(Dir.pwd, "test_cv_format2.pdf")
  File.write(output_path, pdf_content)
  puts "✓ Successfully generated CV PDF!"
  puts "PDF saved at: #{output_path}"
rescue => e
  puts "Error generating CV:"
  puts e.message
  puts e.backtrace
end
