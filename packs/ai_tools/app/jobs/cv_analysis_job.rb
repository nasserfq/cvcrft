# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"

class CvAnalysisJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  # The report is written by two calls that run side by side: one long call
  # took ~42 s, and output length is what costs time. Part A keeps the scores
  # and ATS tips together so the tips cannot contradict the ATS feedback.
  PARTS = %i[scores details].freeze

  # Rough length of each part's reply, in characters, for the progress bar.
  # Arabic replies run longer than English ones.
  EXPECTED_CHARS = {
    "ar" => { scores: 5500, details: 3200 },
    "en" => { scores: 4500, details: 2600 }
  }.freeze

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
    user_prompt = build_user_prompt(@analysis.extracted_text, @analysis.target_job, @analysis.target_industry)
    tracker = ProgressTracker.new(@analysis, EXPECTED_CHARS.fetch(@analysis.language, EXPECTED_CHARS["en"]))

    threads = PARTS.map do |part|
      Thread.new do
        Thread.current.report_on_exception = false
        Rails.application.executor.wrap { request_part(part, user_prompt, tracker) }
      end
    end

    replies = wait_for(threads)
    parsed = replies.to_h { |part, response| [ part, parse_part(response) ] }

    {
      analysis: merge_parts(parsed[:scores], parsed[:details]),
      model: AiModel.default,
      tokens: replies.values.sum { |response| AiModel.token_count(response) || 0 }
    }
  end

  def request_part(part, user_prompt, tracker)
    response = AiModel.complete(system: build_system_prompt(part), user: user_prompt,
                                temperature: 0.3, max_tokens: 8000) do |chunk|
      tracker.add(part, chunk.content.to_s.length)
    end
    [ part, response ]
  end

  # Waits for every part before raising, so no thread is left writing to the
  # analysis after it has been marked failed. Thread#value re-raises the
  # thread's exception. The job may hold the load interlock; letting it go
  # while waiting keeps a thread that needs to autoload from deadlocking.
  def wait_for(threads)
    outcomes = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      threads.map do |thread|
        thread.value
      rescue StandardError => e
        e
      end
    end

    error = outcomes.find { |outcome| outcome.is_a?(Exception) }
    raise error if error

    outcomes.to_h
  end

  def build_system_prompt(part)
    language = @analysis.language == "ar" ? "Arabic" : "English"

    <<~PROMPT
      You are an expert CV/Resume analyst and career coach. Your task is to analyze a CV and provide detailed, actionable feedback.

      IMPORTANT: Respond ONLY in #{language}. All text in your response must be in #{language}.

      #{part == :scores ? scores_instructions : details_instructions}

      LENGTH LIMITS (keep the reply concise):
      - Every feedback text: 2-3 sentences.
      - Every list item: one sentence.

      Return ONLY valid JSON, no additional text or markdown formatting.
    PROMPT
  end

  def scores_instructions
    <<~PROMPT
      You must return a valid JSON object with the following structure:
      {
        "overall_score": <number 0-100>,
        "section_scores": {
          "ats_compatibility": {
            "score": <number 0-100>,
            "feedback": "<feedback about what the CV does well AND what needs improvement>"
          },
          "content_quality": {
            "score": <number 0-100>,
            "feedback": "<feedback>"
          },
          "formatting": {
            "score": <number 0-100>,
            "feedback": "<feedback>"
          },
          "keyword_optimization": {
            "score": <number 0-100>,
            "feedback": "<feedback>"
          },
          "impact_statements": {
            "score": <number 0-100>,
            "feedback": "<feedback>"
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
        "ats_tips": []
      }

      Limits: 3-5 strengths, at most 6 improvements, at most 5 ATS tips.

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

      CRITICAL: Your response MUST be internally consistent. The "ats_tips" section must NOT contradict the "ats_compatibility" feedback. If your ats_compatibility feedback says something is done correctly (like date formatting), do NOT include a tip about fixing it.

      Provide:
      1. Overall score (0-100)
      2. Section-by-section scores and feedback based on what's ACTUALLY in the CV
      3. Top strengths - reference specific things from the CV
      4. Areas for improvement with priorities - only for things that need improving, NOT missing sections that actually exist
      5. ATS optimization tips specific to THIS CV
    PROMPT
  end

  def details_instructions
    <<~PROMPT
      You must return a valid JSON object with the following structure:
      {
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

      Limits: at most 10 keywords in each keyword list; "industry_match" is 2-3 sentences.

      Provide:
      1. Detailed section feedback for sections that EXIST in the CV
      2. Keyword analysis based on the actual content
    PROMPT
  end

  def build_user_prompt(extracted_text, target_job, target_industry)
    context = []
    context << "Target Job: #{target_job}" if target_job.present?
    context << "Target Industry: #{target_industry}" if target_industry.present?

    context_text = context.any? ? "\n\nContext for Analysis:\n#{context.join("\n")}" : ""

    <<~PROMPT
      Analyze the following CV.#{context_text}

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

      Return the structured JSON as specified.
    PROMPT
  end

  def parse_part(response)
    JSON.parse(AiModel.json_body(response.content))
  rescue JSON::ParserError => e
    raise "Failed to parse AI response as JSON: #{e.message}"
  end

  # Same analysis_results shape as the single-call version, so the views and
  # the stored data do not change.
  def merge_parts(scores, details)
    {
      "overall_score" => scores["overall_score"] || 0,
      "section_scores" => scores["section_scores"] || {},
      "strengths" => scores["strengths"] || [],
      "improvements" => scores["improvements"] || [],
      "ats_tips" => scores["ats_tips"] || [],
      "detailed_feedback" => details["detailed_feedback"] || {},
      "keyword_analysis" => details["keyword_analysis"] || {}
    }
  end

  def handle_error(error)
    @analysis.mark_failed!(error.message)
    Rails.logger.error "[CvAnalysis] Failed to analyze CV #{@analysis.id}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
  end

  # Turns streamed characters into a 5-95 % progress value on the analysis.
  # Both part threads report here; writes are throttled and only go up.
  class ProgressTracker
    THROTTLE_SECONDS = 0.75
    FLOOR = 5
    CEILING = 95

    def initialize(analysis, expected_chars, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @analysis = analysis
      @clock = clock
      @expected = expected_chars
      @received = Hash.new(0)
      @written = analysis.progress.to_i
      @last_write_at = nil
      @mutex = Mutex.new
    end

    def add(part, chars)
      @mutex.synchronize do
        @received[part] += chars
        now = @clock.call
        next if @last_write_at && now - @last_write_at < THROTTLE_SECONDS

        value = percent
        next if value <= @written

        ActiveRecord::Base.connection_pool.with_connection { @analysis.update_column(:progress, value) }
        @written = value
        @last_write_at = now
      end
    end

    private

    def percent
      done = @expected.sum { |part, size| [ @received[part], size ].min }
      ratio = done.to_f / @expected.values.sum
      (FLOOR + (CEILING - FLOOR) * ratio).round.clamp(FLOOR, CEILING)
    end
  end
end
