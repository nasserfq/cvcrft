# Builds the copy of a user's personal data that PDPL lets them take with
# them (profile "Download my data"). It only walks User associations so the
# accounts pack never names another pack's models directly.
class UserDataExport
  USER_COLUMNS = %w[
    id email name locale created_at updated_at
    summary_translations_count jobs_translations_count
    job_based_generations_count document_ai_count credit_balance
    privacy_accepted_at privacy_policy_version
  ].freeze

  RESUME_CHILDREN = %i[work_experiences educations skills certifications languages].freeze

  def initialize(user, now: Time.current)
    @user = user
    @now = now
  end

  def as_json(*)
    {
      "user" => user.attributes.slice(*USER_COLUMNS),
      "resumes" => resumes,
      "cv_analyses" => rows(user.cv_analyses),
      "cv_imports" => rows(user.cv_imports),
      "linkedin_imports" => rows(user.linkedin_imports),
      "cv_generations" => cv_generations,
      "ai_translations" => rows(user.ai_translations),
      "coach_chats" => coach_chats,
      "credit_ledger_entries" => rows(user.credit_ledger_entries),
      "credit_purchases" => rows(user.credit_purchases),
      "auto_apply_preference" => user.auto_apply_preference&.attributes,
      "auto_apply_applications" => auto_apply_applications,
      "auto_apply_tokens" => user.auto_apply_tokens.order(:id).map { |t| t.attributes.except("token_digest") },
      "exported_at" => now.iso8601,
      "privacy_policy_version" => PrivacyPolicy::VERSION
    }
  end

  def to_json(*)
    JSON.pretty_generate(as_json)
  end

  def filename
    "seera-data-#{now.to_date.iso8601}.json"
  end

  private

  attr_reader :user, :now

  def rows(scope)
    scope.order(:id).map(&:attributes)
  end

  def resumes
    user.resumes.includes(*RESUME_CHILDREN).order(:id).map do |resume|
      RESUME_CHILDREN.each_with_object(resume.attributes) do |association, row|
        row[association.to_s] = resume.public_send(association).sort_by(&:id).map(&:attributes)
      end
    end
  end

  def cv_generations
    user.cv_generations.order(:id).map do |generation|
      generation.attributes.merge("metadata" => (generation.metadata || {}).except("pdf_data"))
    end
  end

  # Each application with the job it was for; token digests never leave the server.
  def auto_apply_applications
    user.auto_apply_applications.includes(posting: :employer).order(:id).map do |application|
      posting = application.posting
      application.attributes.merge(
        "posting" => { "title" => posting.title, "company" => posting.employer.name, "url" => posting.url, "location" => posting.location }
      )
    end
  end

  def coach_chats
    Coach::Chat.where(user_id: user.id).includes(:messages).order(:id).map do |chat|
      chat.attributes.merge("messages" => chat.messages.sort_by(&:id).map(&:attributes))
    end
  end
end
