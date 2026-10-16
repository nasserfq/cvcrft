module CvGenerator
  # The system and user prompts for one CV generation run. `snapshot` is the
  # CvGenerator::ResumeSnapshot hash of the source resume, or nil for a new CV.
  class PromptBuilder
    def initialize(job_description:, snapshot:)
      @job_description = job_description
      @snapshot = snapshot
    end

    # The system prompt ensures the AI provides ALL necessary structured data for the CV
    def system_prompt
      # ... (This remains the same JSON structure as in the original request, which is correct for generating structured data)
      <<~PROMPT
        You are an expert CV writer and ATS optimization specialist. Your task is to generate a complete, professional CV that will pass Applicant Tracking Systems (ATS) and impress hiring managers.

        CRITICAL REQUIREMENTS:
        1. Generate ONLY real, professional content - NEVER use placeholder text, test data, or sample content
        2. Create a comprehensive CV with multiple work experiences, skills, education, and certifications
        3. Generate content that is specific, measurable, and achievement-focused
        4. Use action verbs and quantifiable results where possible
        5. Ensure all content is relevant to the job description provided
        6. Write in clear, professional English suitable for international job applications
        7. Create enough content to fill 2-3 pages professionally

        FORMAT REQUIREMENTS:
        Return your response in JSON format with the following structure:
        {
          "professional_summary": "A compelling 3-4 sentence professional summary tailored to the job description",
          "work_experiences": [
            {
              "job_title": "Senior Software Engineer",
              "company": "TechCorp Solutions",
              "start_date": "2022-01",
              "end_date": null,
              "responsibilities": [
                "Led development of microservices architecture serving 100K+ users",
                "Mentored team of 5 junior developers and improved code quality by 40%",
                "Implemented CI/CD pipelines reducing deployment time by 60%",
                "Collaborated with product managers to deliver features 25% faster"
              ]
            }
            // ... more experiences
          ],
          "skills": [
            {
              "category": "Technical Skills",
              "names": ["JavaScript", "Python", "React", "Node.js", "PostgreSQL", "AWS", "Docker", "Git"]
            }
            // ... more skills
          ],
          "educations": [
            // ... education entries
          ],
          "certifications": [
            // ... certification entries
          ],
          "languages": [
            // ... language entries
          ],
          "ats_optimization_notes": "Optimized for ATS with relevant keywords, quantifiable achievements, and standard formatting",
          "generation_notes": "Generated comprehensive CV with realistic content tailored to job requirements"
        }

        IMPORTANT: Generate a complete, professional CV with enough content to create a compelling 2-3 page document. Include realistic work experiences, achievements, and skills that match the job description.
      PROMPT
    end

    def user_prompt
      existing_cv_data = @snapshot ? existing_cv_context : ""
      base_requirements = []

      if @snapshot
        # Focus only on updating the professional summary while preserving other sections
        base_requirements += [
          "IMPORTANT: Keep ALL existing work experience, skills, education, certifications, and languages exactly as they are",
          "ONLY generate a new professional summary that aligns with the job description",
          "Analyze the existing experience and skills to craft a targeted summary",
          "Highlight the most relevant aspects of the existing experience for this specific role",
          "Ensure the summary connects past achievements to the new role's requirements"
        ]
      else
        base_requirements += [
          "Generate a complete CV with all sections based on the job description",
          "Create realistic and relevant content that demonstrates expertise in the required areas",
          "Include quantifiable achievements and metrics where appropriate"
        ]
      end

      # Common requirements for the professional summary
      base_requirements += [
        "Make the professional summary concise and impactful (3-4 sentences)",
        "Include relevant keywords from the job description",
        "Emphasize achievements and skills that match the role",
        "Use strong action verbs and specific metrics"
      ]

      # The second line of each multi-line string below keeps its leading
      # spaces on purpose: they are part of the prompt the model has always seen
      # (test/fixtures/files/cv_generator/*.txt pins it byte for byte).
      <<~PROMPT
        #{if @snapshot
            "Please update ONLY the professional summary of the existing CV to target the following job description.#{' '}
           Keep all other sections (work experience, skills, education, etc.) EXACTLY as they are."
          else
            "Please generate a complete, professional CV for the following job description:"
          end}

        JOB DESCRIPTION:
        "#{@job_description}"

        #{existing_cv_data}

        REQUIREMENTS:
        #{base_requirements.map.with_index(1) { |req, i| "#{i}. #{req}" }.join("\n")}

        #{if @snapshot
            "IMPORTANT: Return the existing CV data structure with ONLY the professional_summary field updated.#{' '}
           DO NOT modify any other fields (work_experiences, skills, education, certifications, languages)."
          end}

        Return the data in the JSON format specified in the system prompt.
      PROMPT
    end

    private

    def existing_cv_context
      return "" unless @snapshot

      # Use the formatted data
      context = @snapshot

      # Create a formatted string with the existing CV data
      <<~EXISTING_CV
        EXISTING CV DATA:
        Please use the following existing CV data as a base and adapt it for the new job description.
        Keep relevant experiences and skills exactly as they are, ONLY update the professional summary.

        #{JSON.pretty_generate(context)}

        INSTRUCTIONS:
        1. Keep ALL existing experience data exactly as is - DO NOT modify any dates, companies, or responsibilities
        2. Keep ALL existing skills, education, certifications, and languages exactly as is
        3. ONLY rewrite the professional summary to target the new position
        4. Ensure the new summary highlights the most relevant aspects of the existing experience
        5. Focus on connecting past achievements to the new role requirements
      EXISTING_CV
    end
  end
end
