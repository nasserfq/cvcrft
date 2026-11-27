module JobApplications
  # Approve, skip or answer one of the user's applications, and open its CV or proof.
  # Rows are looked up through current_user, so another user's id is a 404.
  class ApplicationsController < BaseController
    include UserRateLimit

    # Served inline only as one of these; anything else downloads as bytes.
    INLINE_TYPES = %w[application/pdf image/jpeg image/png text/plain].freeze

    rate_limit_per_user to: 30, within: 1.minute, only: %i[approve skip answer], name: "seera-apply-application"
    before_action :set_application

    def approve
      finish(@application.approve!, "approved")
    end

    def skip
      finish(@application.skip!, "skipped")
    end

    def answer
      finish(@application.answer!(answer_params), "saved")
    end

    def cv
      send_document(@application.cv_pdf)
    end

    def proof
      send_document(@application.proof)
    end

    private

    def set_application
      @application = Application.where(user: current_user).find(params[:id])
    end

    def finish(moved, notice)
      if moved
        redirect_to my_jobs_root_path, notice: t("seera_apply.flash.#{notice}")
      else
        redirect_to my_jobs_root_path, alert: t("seera_apply.flash.stale")
      end
    end

    # Only the questions still missing; multi-choice checkboxes come as lists.
    def answer_params
      permitted = @application.missing.map do |id|
        question = @application.questions.find { |q| q["id"].to_s == id }
        multi = question && question["type"] == "checkbox" && Array(question["options"]).any?
        multi ? { id => [] } : id
      end
      values = params.fetch(:answers, {}).permit(*permitted).to_h
      values.transform_values { |value| value.is_a?(Array) ? value.compact_blank.presence : value.to_s.strip }
    end

    def send_document(document)
      raise ActiveRecord::RecordNotFound unless document

      type = document.content_type == "message/rfc822" ? "text/plain" : document.content_type
      inline = INLINE_TYPES.include?(type)
      send_data document.data, type: inline ? type : "application/octet-stream",
                               disposition: inline ? "inline" : "attachment", filename: document.filename
    end
  end
end
