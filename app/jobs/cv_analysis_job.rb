# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"

class CvAnalysisJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(cv_analysis_id)
    @analysis = CvAnalysis.find(cv_analysis_id)
    @analysis.mark_processing!

    Rails.logger.info "[CvAnalysis] Starting analysis for #{@analysis.id}"

    begin
      result = analyze_cv
      @analysis.mark_completed!(
        result[:analysis],
        result[:model],
        result[:tokens]
      )
      Rails.logger.info "[CvAnalysis] Successfully analyzed CV #{@analysis.id}"
    rescue => e
      handle_error(e)
      raise e
    end
  end

  private

  def analyze_cv

    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(@analysis.extracted_text, @analysis.target_job, @analysis.target_industry)

    response = AiModel.complete(system: system_prompt, user: user_prompt,
                                temperature: 0.3, max_tokens: 4000)
    analysis_result = parse_openai_response(response)

    tokens_used = AiModel.token_count(response) || 0

    {
      analysis: analysis_result,
      model: "gpt-4.1-mini",
      tokens: tokens_used
    }
  end

  def build_system_prompt
    language = @analysis.language == "ar" ? "Arabic" : "English"

    <<~PROMPT
      You are an expert CV/Resume analyst and career coach. Your task is to analyze a CV and provide detailed, actionable feedback.

      IMPORTANT: Respond ONLY in #{language}. All text in your response must be in #{language}.

      You must return a valid JSON object with the following structure:
      {
        "overall_score": <number 0-100>,
        "section_scores": {
          "ats_compatibility": {
            "score": <number 0-100>,
            "feedback": "<detailed feedback about what the CV does well AND what needs improvement>"
          },
          "content_quality": {
            "score": <number 0-100>,
            "feedback": "<detailed feedback>"
          },
          "formatting": {
            "score": <number 0-100>,
            "feedback": "<detailed feedback>"
          },
          "keyword_optimization": {
            "score": <number 0-100>,
            "feedback": "<detailed feedback>"
          },
          "impact_statements": {
            "score": <number 0-100>,
            "feedback": "<detailed feedback>"
          }
        },
        "strengths": [
          "<strength 1>",
          "<strength 2>",
          "<strength 3>"
        ],
        "improvements": [
          {
            "issue": "<what's wrong>",
            "suggestion": "<how to fix it>",
            "priority": "<high|medium|low>"
          }
        ],
        "ats_tips": [],
        "detailed_feedback": {
          "professional_summary": "<feedback on summary section>",
          "work_experience": "<feedback on work experience>",
          "education": "<feedback on education section>",
          "skills": "<feedback on skills section>",
          "overall_structure": "<feedback on document structure>"
        },
        "keyword_analysis": {
          "found_keywords": ["<keyword1>", "<keyword2>"],
          "missing_keywords": ["<suggested keyword1>", "<suggested keyword2>"],
          "industry_match": "<assessment of industry keyword alignment>"
        }
      }

      SCORING CRITERIA:

      1. ATS Compatibility (0-100):
         - Parseable format without tables or columns
         - Standard section headings
         - No headers/footers with critical info
         - Clean text formatting
         - Proper date formats

      2. Content Quality (0-100):
         - Clear, concise language
         - Achievement-oriented statements
         - Quantified accomplishments
         - Relevant experience highlighted
         - No spelling/grammar errors

      3. Formatting (0-100):
         - Consistent styling
         - Professional appearance
         - Appropriate length
         - Logical section order
         - White space balance

      4. Keyword Optimization (0-100):
         - Industry-relevant keywords
         - Job-specific terminology
         - Skills alignment
         - Action verbs usage

      5. Impact Statements (0-100):
         - Measurable achievements
         - Results-focused descriptions
         - Clear value proposition
         - Specific accomplishments

      CRITICAL - ATS TIPS RULES:
      The "ats_tips" array MUST follow these rules strictly:
      1. ONLY include tips for issues that ACTUALLY exist in the CV
      2. If the CV already has proper date formatting, do NOT suggest fixing dates
      3. If the CV already uses standard headings, do NOT suggest adding them
      4. If the CV has no tables/columns, do NOT suggest removing them
      5. Each tip must address a REAL problem you identified, not hypothetical issues
      6. If the ATS score is 80% or higher, limit tips to 2-3 minor improvements only
      7. NEVER contradict the ats_compatibility feedback - tips must be consistent with it

      Return ONLY valid JSON, no additional text or markdown formatting.
    PROMPT
  end

  def build_user_prompt(extracted_text, target_job, target_industry)
    context = []
    context << "Target Job: #{target_job}" if target_job.present?
    context << "Target Industry: #{target_industry}" if target_industry.present?

    context_text = context.any? ? "\n\nContext for Analysis:\n#{context.join("\n")}" : ""

    <<~PROMPT
      Analyze the following CV and provide detailed feedback with scores.#{context_text}

      CRITICAL: Your response MUST be internally consistent. The "ats_tips" section must NOT contradict the "ats_compatibility" feedback. If your ats_compatibility feedback says something is done correctly (like date formatting), do NOT include a tip about fixing it.

      IMPORTANT INSTRUCTIONS:
      - Carefully read and analyze the ACTUAL content of the CV below
      - Base ALL your feedback on what is ACTUALLY present in the CV
      - Do NOT suggest adding sections that already exist in the CV
      - If a section exists (like Work Experience or Education), provide feedback on how to IMPROVE it, not to add it
      - Only suggest adding sections that are genuinely MISSING from the CV
      - Be specific and reference actual content from the CV when giving feedback

      CV Content:
      ---
      #{extracted_text}
      ---

      Provide a comprehensive analysis with:
      1. Overall score (0-100)
      2. Section-by-section scores and feedback based on what's ACTUALLY in the CV
      3. Top strengths (at least 3) - reference specific things from the CV
      4. Areas for improvement with priorities - only for things that need improving, NOT missing sections that actually exist
      5. ATS optimization tips specific to THIS CV
      6. Detailed section feedback for sections that EXIST in the CV
      7. Keyword analysis based on the actual content

      Return the structured JSON analysis as specified.
    PROMPT
  end


  def parse_openai_response(response)
    content = response.content

    # Try to extract JSON from the response
    json_match = content.match(/```json\s*(.*?)\s*```/m)
    json_content = json_match ? json_match[1] : content

    begin
      parsed = JSON.parse(json_content)

      # Validate and normalize the response structure
      {
        "overall_score" => parsed["overall_score"] || 0,
        "section_scores" => parsed["section_scores"] || {},
        "strengths" => parsed["strengths"] || [],
        "improvements" => parsed["improvements"] || [],
        "ats_tips" => parsed["ats_tips"] || [],
        "detailed_feedback" => parsed["detailed_feedback"] || {},
        "keyword_analysis" => parsed["keyword_analysis"] || {}
      }
    rescue JSON::ParserError => e
      raise "Failed to parse AI response as JSON: #{e.message}"
    end
  end

  def handle_error(error)
    @analysis.mark_failed!(error.message)
    Rails.logger.error "[CvAnalysis] Failed to analyze CV #{@analysis.id}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
  end
end
