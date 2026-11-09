class Api::TranslationsController < ApplicationController
  include CreditsUpsell
  before_action :authenticate_user!

  include UserRateLimit
  rate_limit_per_user to: 20, within: 1.minute, only: %i[translate_professional_summary translate_job_descriptions], name: "translate"
  rate_limit_per_user to: 10, within: 1.minute, only: :export_pdf, name: "pdf"
  include AiCapacity
  refuse_when_ai_busy only: %i[translate_professional_summary translate_job_descriptions]

  def translate_professional_summary
    begin
      # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
      remaining = usage_limits.remaining_summary_translations
      return render_translation_limit(:summary_translation) unless Billing::UsageGate.available?(current_user, :summary_translation)

      resume_id = owned_resume_id
      arabic_text = params[:arabic_text]

      # Validate input
      if arabic_text.blank?
        render json: { error: "Arabic text is required" }, status: :unprocessable_entity
        return
      end

      translation = build_translation(arabic_text, resume_id,
                                      "temperature" => 0.7, "max_tokens" => 500, "professional_summary" => true)
      return render_invalid_translation(translation) unless translation.valid?

      job_id = translation.metadata["job_id"]
      charge = Billing::UsageGate.allow!(current_user, :summary_translation, key: job_id)
      return render_translation_limit(:summary_translation) if charge == :blocked

      enqueue_translation(translation, charge, :summary_translation)

      # Track translation event
      track_event("translation_requested", {
        type: "professional_summary",
        resume_id: resume_id,
        remaining: projected_remaining(remaining)
      })

      render json: {
        job_id: job_id,
        status: "queued",
        remaining_summary: projected_remaining(remaining),
        unlimited: usage_limits.unlimited?,
        **charge_json(charge, :summary_translation),
        message: "Translation job has been queued. Please poll for status."
      }
    rescue => e
      translation_enqueue_failed(translation, charge, :summary_translation, job_id, e)
    end
  end

  def translate_job_descriptions
    begin
      # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
      remaining = usage_limits.remaining_jobs_translations
      return render_translation_limit(:jobs_translation) unless Billing::UsageGate.available?(current_user, :jobs_translation)

      resume_id = owned_resume_id
      job_descriptions = params[:job_descriptions] # Array of {index, job_title, company, responsibilities}

      if job_descriptions.blank? || !job_descriptions.is_a?(Array)
        render json: { error: "Job descriptions array is required" }, status: :unprocessable_entity
        return
      end

      # Filter out empty job descriptions
      valid_jobs = job_descriptions.select do |job|
        job["responsibilities"]&.any? { |r| r.to_s.strip.present? }
      end

      if valid_jobs.empty?
        render json: { error: "No job descriptions with responsibilities to translate" }, status: :unprocessable_entity
        return
      end

      # Combine all job descriptions into one text for efficient translation
      combined_text = valid_jobs.map do |job|
        responsibilities = job["responsibilities"]&.select(&:present?)&.join("\n") || ""
        "[#{job['job_title']} - #{job['company']}]\n#{responsibilities}"
      end.join("\n\n---\n\n")

      translation = build_translation(combined_text, resume_id,
                                      "temperature" => 0.7, "max_tokens" => 2000, "job_descriptions" => true,
                                      "job_indices" => valid_jobs.map { |j| j["index"] })
      return render_invalid_translation(translation) unless translation.valid?

      job_id = translation.metadata["job_id"]
      charge = Billing::UsageGate.allow!(current_user, :jobs_translation, key: job_id)
      return render_translation_limit(:jobs_translation) if charge == :blocked

      enqueue_translation(translation, charge, :jobs_translation)

      # Track translation event
      track_event("translation_requested", {
        type: "job_descriptions",
        resume_id: resume_id,
        job_count: valid_jobs.size,
        remaining: projected_remaining(remaining)
      })

      render json: {
        job_id: job_id,
        status: "queued",
        job_count: valid_jobs.size,
        remaining_jobs: projected_remaining(remaining),
        unlimited: usage_limits.unlimited?,
        **charge_json(charge, :jobs_translation),
        message: "Translation job has been queued for #{valid_jobs.size} job descriptions."
      }
    rescue => e
      translation_enqueue_failed(translation, charge, :jobs_translation, job_id, e)
    end
  end

  def translation_status
    begin
      job_id = params[:id]

      # Find the translation by job_id stored in metadata
      translation = AiTranslation.where(user_id: current_user.id)
                               .where("metadata->>'job_id' = ?", job_id)
                               .order(created_at: :desc)
                               .first

      if translation
        # Parse the metadata to get the structured translation data
        metadata = translation.metadata || {}

        # Check if this is a job descriptions translation
        is_job_descriptions = metadata["job_descriptions"] == true

        response_data = {
          id: translation.id,
          job_id: job_id,
          status: translation.status,
          arabic_text: translation.arabic_text,
          english_text: translation.english_text,
          translation_quality: translation.translation_quality,
          tokens_used: translation.tokens_used,
          created_at: translation.created_at,
          updated_at: translation.updated_at,
          # Add structured data from metadata
          skills_extracted: metadata["skills_extracted"] || [],
          translation_notes: metadata["translation_notes"] || "",
          # Job descriptions specific data
          job_descriptions: is_job_descriptions,
          job_indices: metadata["job_indices"] || [],
          # Short reason for a failure (see AiTranslationJob.error_code_for)
          error_code: (metadata["error_code"] if translation.status == "failed"),
          # The resume's updated_at after the job saved the summary on it, so
          # the builder's next autosave is not taken for another tab's.
          resume_updated_at: metadata["resume_updated_at"],
          # Include remaining counts so frontend can update after completion/failure
          remaining_summary: usage_limits.remaining_summary_translations,
          remaining_jobs: usage_limits.remaining_jobs_translations
        }

        # Parse jobs from english_text if this is a job descriptions translation
        if is_job_descriptions && translation.english_text.present?
          begin
            parsed = JSON.parse(translation.english_text)
            response_data[:jobs] = parsed["jobs"] || []
          rescue JSON::ParserError
            response_data[:jobs] = []
          end
        end

        render json: response_data
      else
        # The row is saved before the job is queued, so no row means no such
        # translation for this user.
        render json: { job_id: job_id, status: "not_found", error: "Translation not found" }, status: :not_found
      end
    rescue => e
      Rails.logger.error "Translation status API error: #{e.message}"
      render json: { error: "Failed to get translation status", message: e.message }, status: :internal_server_error
    end
  end

  # Sends the PDF of one of the user's saved resumes. The builder saves the
  # resume first and downloads it from here; profile and resume pages link
  # here directly.
  def export_pdf
    track_event("pdf_exported", { resume_id: params[:resume_id] })

    if params[:resume_id].blank?
      Rails.logger.error "Invalid parameters for PDF export"
      return render json: { error: "Invalid parameters" }, status: :bad_request
    end

    result = CvBuilderPdfJob.new.perform(
      "user_id" => current_user.id,
      "resume_id" => params[:resume_id],
      "view_in_browser" => params[:view_in_browser] == "true",
      "template" => AtsTemplatePdfService.normalize_template_key(params[:template])
    )

    if result[:status] == "success" && result[:file_path].present? && File.exist?(result[:file_path])
      send_file result[:file_path],
        filename: result[:filename] || "resume.pdf",
        type: "application/pdf",
        disposition: "attachment"
    else
      Rails.logger.error "PDF generation failed: #{result[:message]}"
      render json: { error: "PDF generation failed" }, status: :internal_server_error
    end
  rescue => e
    Rails.logger.error "Error with PDF export: #{e.class} - #{e.message}"
    render json: { error: "PDF generation failed" }, status: :internal_server_error
  end

  # Endpoint to get translation limit info (must be above private). `credits`
  # says, per kind, whether the next use is free, will use a credit, or is
  # blocked, so the page can warn "this will use 1 credit".
  def translation_limit
    credits = Billing::UsageGate.quote(current_user, %i[summary_translation jobs_translation])
    render json: usage_limits.as_json.merge(credits: credits, **credits_upsell)
  end

  private

  # resume_id comes from the request; only the user's own resumes may be named.
  def owned_resume_id
    return nil if params[:resume_id].blank?

    current_user.resumes.find(params[:resume_id]).id
  end

  def usage_limits
    current_user.usage_limits
  end

  LIMIT_MAX_METHODS = {
    summary_translation: :max_summary_translations,
    jobs_translation: :max_jobs_translations
  }.freeze

  # Free allowance used up and no credit to fall back on.
  def render_translation_limit(kind)
    max = usage_limits.public_send(LIMIT_MAX_METHODS.fetch(kind)) || "∞"
    variant = Billing.enabled_for?(current_user) ? "no_credits" : "limit_reached"
    render json: {
      error: t("ux_overage.translations.#{kind}.#{variant}", max: max),
      limit_reached: true,
      remaining: 0,
      **credits_upsell
    }, status: :too_many_requests
  end

  def charge_json(charge, kind)
    return { charged: "free" } unless charge == :credit

    { charged: "credit", credits_spent: Billing::UsageGate.cost(kind), credit_balance: current_user.credit_balance }
  end

  def projected_remaining(current_remaining)
    return nil if usage_limits.unlimited?

    [ current_remaining - 1, 0 ].max
  end

  # The translation row is saved before the job is queued, so the status
  # endpoint and the stale sweeper see it from the start.
  def build_translation(text, resume_id, options)
    current_user.ai_translations.new(
      arabic_text: text,
      resume_id: resume_id,
      ai_model: AiModel.default,
      status: "pending",
      metadata: options.merge("job_id" => SecureRandom.hex(12))
    )
  end

  def render_invalid_translation(translation)
    messages = translation.errors.full_messages
    render json: { error: messages.to_sentence, errors: messages }, status: :unprocessable_entity
  end

  def enqueue_translation(translation, charge, kind)
    translation.metadata["overage_kind"] = kind.to_s if charge == :credit
    translation.save!
    options = translation.metadata.merge("translation_id" => translation.id)
    jid = AiTranslationJob.perform_async(translation.arabic_text, current_user.id, translation.resume_id, options)
    Rails.logger.info "[AI Translate] #{kind} queued: jid=#{jid}, job_id=#{translation.metadata['job_id']}"
  end

  # Queueing failed after the charge: the row (if saved) is failed and the
  # credit given back.
  def translation_enqueue_failed(translation, charge, kind, job_id, error)
    if translation&.persisted?
      translation.fail_unfinished!(error.message, error_code: "internal")
    elsif charge == :credit
      Billing::UsageGate.refund!(current_user, kind, key: job_id)
    end
    Rails.logger.error "[AI Translate] #{kind} error: #{error.message}"
    Rails.logger.error "Backtrace: #{Array(error.backtrace).first(5).join("\n")}"
    render json: { error: "Translation failed", message: error.message }, status: :internal_server_error
  end
end
