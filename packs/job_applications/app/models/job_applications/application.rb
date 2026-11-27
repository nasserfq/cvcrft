module JobApplications
  # One application Seera sends for a user to one posting. Every status write
  # is a conditional update (transition!) or happens under the profile lock in
  # Sender, so two workers can never move the same row. See
  # docs/state-machines.md "Seera Apply applications".
  class Application < ApplicationRecord
    STATUSES = %w[preparing needs_answer needs_approval queued sending sent failed_fallback skipped].freeze
    TERMINAL = %w[sent failed_fallback skipped].freeze
    ERROR_CODES = %w[unsupported no_form captcha unknown_field timeout closed unconfirmed prepare_failed send_error dry_run].freeze
    HOLDS = %w[paused daily_cap no_credits].freeze # only on queued rows
    CHANNELS = %w[browser email manual].freeze
    CHARGES = %w[free credit uncollected].freeze
    MAX_ATTEMPTS = 3
    DOCUMENT_RETENTION = 90.days
    ANSWER_RETENTION = 180.days

    belongs_to :user
    belongs_to :posting, class_name: "JobApplications::Posting"
    has_many :documents, class_name: "JobApplications::Document", inverse_of: :application, dependent: :delete_all

    validates :status, inclusion: { in: STATUSES }
    validates :channel, inclusion: { in: CHANNELS }
    validates :error_code, inclusion: { in: ERROR_CODES }, allow_nil: true
    validates :hold, inclusion: { in: HOLDS }, allow_nil: true
    validates :charge, inclusion: { in: CHARGES }, allow_nil: true
    validates :posting_id, uniqueness: { scope: :user_id }

    scope :active, -> { where.not(status: TERMINAL) }

    def terminal? = TERMINAL.include?(status)
    def cv_pdf = documents.find_by(kind: "cv_pdf")
    def proof = documents.find_by(kind: "proof")

    # Moves the row from `from` (a status or a list) to `to` only if it is
    # still there. Returns true for the one caller that moved it.
    def transition!(from:, to:, **attrs)
      raise ArgumentError, "unknown status #{to}" unless STATUSES.include?(to)

      changes = attrs.merge(status: to, updated_at: Time.current)
      moved = self.class.where(id:, status: from).update_all(changes) == 1
      reload if moved
      moved
    end

    # preparing -> needs_answer (required questions unanswered),
    # needs_approval (fewer than APPROVALS_REQUIRED sent) or queued.
    # DispatchJob sends queued rows, which paces them.
    def finish_pack!(questions:, answers:, missing:, summary:, cover_letter: nil)
      approval = approval_needed?
      to = if missing.any? then "needs_answer"
      elsif approval then "needs_approval"
      else "queued"
      end
      transition!(from: "preparing", to:, questions:, answers:, missing: missing.map(&:to_s), summary:, cover_letter:,
                                     approval_required: approval, error_code: nil)
    end

    # Takes the user's answers to the questions in `missing` (other ids are
    # ignored), remembers the non-sensitive ones on the profile, and moves on
    # once nothing required is left.
    def answer!(values)
      values = values.to_h.transform_keys(&:to_s).slice(*missing).compact_blank
      return false if values.empty? || status != "needs_answer"

      merged = answers.merge(values)
      still_missing = missing - values.keys
      moved =
        if still_missing.any?
          transition!(from: "needs_answer", to: "needs_answer", answers: merged, missing: still_missing)
        else
          approval = approval_required || approval_needed?
          transition!(from: "needs_answer", to: approval ? "needs_approval" : "queued", answers: merged, missing: [],
                                            approval_required: approval)
        end
      remember_answers(values) if moved
      moved
    end

    # Submitters call this just before they click Submit (or once SES accepts
    # an email). False means the row is no longer theirs: don't click.
    def mark_submit_clicked!
      now = Time.current
      marked = self.class.where(id:, status: "sending", submit_clicked_at: nil).update_all(submit_clicked_at: now, updated_at: now) == 1
      self.submit_clicked_at = now if marked
      marked
    end

    def approve!
      moved = transition!(from: "needs_approval", to: "queued", approved_at: Time.current, hold: nil)
      SendJob.perform_later(id) if moved
      moved
    end

    def skip!
      transition!(from: %w[needs_approval needs_answer queued], to: "skipped", hold: nil)
    end

    # Ends any unfinished row with an error code. Never charged.
    def fallback!(code)
      raise ArgumentError, "unknown error code #{code}" unless ERROR_CODES.include?(code.to_s)

      transition!(from: STATUSES - TERMINAL, to: "failed_fallback", error_code: code.to_s, hold: nil)
    end

    # Sweeper (StaleWorkSweeperJob). Returns how many rows it moved or charged.
    def self.fail_stale!(older_than:)
      count = 0
      where(status: "preparing", updated_at: ...older_than).find_each do |app|
        count += 1 if app.fallback!("prepare_failed")
      end
      where(status: "sending", claimed_at: ...older_than).find_each do |app|
        count += 1 if fail_stale_send(app)
      end
      where(status: "sent", charge: nil, sent_at: ...older_than).find_each do |app|
        count += 1 if Sender.new(app).charge!
      end
      count
    end

    # A send left in sending: before the click it can go out again; after the
    # click it may have reached the employer, so it is never resubmitted.
    def self.fail_stale_send(app)
      return app.fallback!("unconfirmed") if app.submit_clicked_at

      changes = app.attempts >= MAX_ATTEMPTS ? { status: "failed_fallback", error_code: "timeout" } : { status: "queued", claimed_at: nil }
      where(id: app.id, status: "sending", submit_clicked_at: nil).update_all(changes.merge(updated_at: Time.current)) == 1
    end
    private_class_method :fail_stale_send

    # Retention: documents of rows finished over 90 days ago, and the answers
    # and cover letter of rows finished over 180 days ago.
    def self.purge_old!
      Document.where(application_id: where(status: TERMINAL, updated_at: ...DOCUMENT_RETENTION.ago).select(:id)).delete_all
      where(status: TERMINAL, updated_at: ...ANSWER_RETENTION.ago).where("answers <> '{}'::jsonb OR cover_letter IS NOT NULL")
        .update_all(answers: {}, cover_letter: nil)
    end

    private

    def approval_needed?
      self.class.where(user_id:, status: "sent").count < APPROVALS_REQUIRED
    end

    # Saved by question label for the next form. Sensitive questions and
    # file fields are never remembered.
    def remember_answers(values)
      by_label = values.filter_map do |question_id, value|
        question = questions.find { |q| q["id"].to_s == question_id }
        next unless question && question["type"] != "file" && !sensitive_label?(question["label"].to_s)

        [ question["label"], value ]
      end
      Profile.find_by(user_id:)&.remember_answers!(by_label)
    end

    # JobApplications::Sensitive comes with the apply pack; until it exists
    # every label counts as sensitive, so nothing is remembered.
    def sensitive_label?(label)
      sensitive = "JobApplications::Sensitive".safe_constantize
      sensitive.nil? || sensitive.match?(label)
    end
  end
end
