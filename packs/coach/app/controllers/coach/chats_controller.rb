module Coach
  class ChatsController < ApplicationController
    before_action :authenticate_user!, :require_coach!
    before_action :set_chat, only: %i[show message accept reject send_to_seera]

    # Same cap as CvImportsController.
    MAX_PDF_SIZE = 10.megabytes

    def index
      @resumes = ResumeBuilder::PublicApi.list(current_user)
    end

    def create
      return start_import if params[:path] == "import"

      chat = Coach::Chat.transaction do
        Coach::Chat.create!(user: current_user, path: params[:path]).tap do |c|
          # The coach opens with a question, so the user isn't facing an empty chat.
          c.messages.create!(role: "assistant", content: t("coach.first_question"),
                             fields: [ t("coach.first_name"), t("coach.last_name") ])
        end
      end
      redirect_to coach_chat_path(chat)
    end

    def show
      @messages = @chat.messages.order(:id).map { |m| m.slice(:id, :role, :content, :fields) }
    end

    def accept
      settle_proposal { |draft, p| Coach::Draft.rewrite(draft, p["section"], p["index"], p["after"]) }
    end

    def reject
      settle_proposal { |draft, _proposal| draft }
    end

    def send_to_seera
      return redirect_to coach_chat_path(@chat), alert: t("coach.send_to_seera.empty") if @chat.draft.blank?

      resume = ResumeBuilder::PublicApi.create_from_draft(current_user, @chat.draft)
      redirect_to resume_path(resume)
    end

    def message
      if Coach.daily_count(current_user) >= Coach::DAILY_LIMIT
        return render json: { error: t("coach.daily_cap", limit: Coach::DAILY_LIMIT) }, status: :too_many_requests
      end

      message = @chat.messages.new(role: "user", content: params[:content])
      return head :unprocessable_entity unless message.save

      Coach::TurnJob.perform_later(@chat.id)
      head :accepted
    end

    private

    # A Seera resume is copied into the draft now; a PDF's text becomes the first message and TurnJob extracts it.
    def start_import
      if params[:resume_id].present?
        # list only holds the user's own resumes, so another user's id is a 404.
        resume = ResumeBuilder::PublicApi.list(current_user).find { |r| r["id"].to_s == params[:resume_id].to_s }
        raise ActiveRecord::RecordNotFound unless resume

        draft = Coach::Draft.clean(ResumeBuilder::PublicApi.read(current_user, resume["id"]))
        content = t("coach.import.review_seera", title: resume["title"])
      else
        error = pdf_error(params[:pdf_file])
        return import_failed(error) if error

        draft = {}
        # Trimmed to fit Coach::Message's content limit.
        content = CvPdfImportService.new(params[:pdf_file].path).parse[:text].first(20_000)
      end

      chat = Coach::Chat.transaction do
        Coach::Chat.create!(user: current_user, path: "import", draft:).tap { |c| c.messages.create!(role: "user", content:) }
      end
      Coach::TurnJob.perform_later(chat.id)
      redirect_to coach_chat_path(chat)
    rescue CvPdfImportService::CorruptedFileError, CvPdfImportService::CvPdfParseError
      import_failed(t("coach.import.unreadable"))
    end

    # Checked here, before the file is parsed.
    def pdf_error(file)
      return t("coach.import.not_pdf") unless file.respond_to?(:content_type) && file.content_type == "application/pdf"

      t("coach.import.too_big") if file.size > MAX_PDF_SIZE
    end

    def import_failed(message)
      flash.now[:alert] = message
      index
      render :index, status: :unprocessable_entity
    end

    # Locked and reloaded so a running turn's propose_rewrite can't race it; accept re-validates through Coach::Draft.
    def settle_proposal
      id = params[:proposal_id].to_s
      found = @chat.with_lock do
        proposal = @chat.proposals.find { |p| p["id"] == id }
        proposal && @chat.update!(draft: yield(@chat.draft, proposal), proposals: @chat.proposals - [ proposal ])
      end
      return head :not_found unless found

      Coach.broadcast(@chat, type: "draft", draft: @chat.draft) if @chat.saved_change_to_draft?
      head :ok
    rescue Coach::Draft::Invalid
      # The draft changed since it was proposed (e.g. that job was removed), so drop it.
      @chat.update!(proposals: @chat.proposals.reject { |p| p["id"] == id })
      head :unprocessable_entity
    end

    def require_coach!
      raise ActionController::RoutingError, "Not Found" unless Coach.enabled_for?(current_user)
    end

    def set_chat
      @chat = Coach::Chat.where(user: current_user).find(params[:id])
    end
  end
end
