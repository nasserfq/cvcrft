require "aws-sdk-ses"
require "mail"

module JobApplications
  module Submitters
    # Emails the application to the address in the posting, through SES, from
    # Seera's sender with the user's name on it. Replies go to the user, who is
    # also on Cc. English only: the employer reads it.
    class Email
      VISA_LABELS = {
        "saudi_citizen" => "Saudi citizen",
        "gcc_citizen" => "GCC citizen",
        "iqama_transferable" => "Iqama holder, transferable",
        "iqama_not_transferable" => "Iqama holder, not transferable",
        "needs_sponsorship" => "Needs visa sponsorship"
      }.freeze
      NOTICE_LABELS = {
        "immediate" => "Immediate",
        "two_weeks" => "Two weeks",
        "one_month" => "One month",
        "two_months" => "Two months",
        "three_months" => "Three months"
      }.freeze
      PROOF_TYPE = "message/rfc822".freeze
      # SES and network failures happen before anything reaches the employer.
      SEND_ERRORS = [ Aws::SES::Errors::ServiceError, Seahorse::Client::NetworkingError ].freeze

      def self.questions(_posting) = []

      attr_reader :application

      def initialize(application, cv_pdf:)
        @application = application
        @cv_pdf = cv_pdf
      end

      def call
        return Result.fallback("unsupported") if posting.apply_email.blank? || user.email.blank?

        mail = build
        # Built but never sent; the proof shows what would have gone out.
        return Result.fallback("dry_run", proof_bytes: proof(mail), proof_type: PROOF_TYPE) if JobApplications.dry_run?

        message_id = send_raw(mail)
        application.mark_submit_clicked!
        Result.sent(proof_bytes: proof(mail), proof_type: PROOF_TYPE, message_id:, url: nil,
                    text: "Emailed to #{posting.apply_email}")
      end

      def build(attach: true)
        mail = Mail.new
        mail.from = from_address
        mail.reply_to = user.email
        mail.to = posting.apply_email
        mail.cc = user.email
        mail.subject = "Application: #{posting.title.to_s.squish} – #{name}"
        mail.charset = "UTF-8"
        mail.text_part = Mail::Part.new(content_type: "text/plain; charset=UTF-8", body: body)
        mail.attachments[cv_filename] = { mime_type: "application/pdf", content: @cv_pdf } if attach
        mail
      end

      private

      def posting = application.posting
      def user = application.user
      def profile = @profile ||= Profile.find_by!(user_id: application.user_id)

      def send_raw(mail)
        AmazonSesService.new.send_raw(mail)
      rescue *SEND_ERRORS => e
        raise Retryable, "SES: #{e.class}: #{e.message}"
      end

      def from_address
        sender = Rails.application.credentials.dig(:aws, :from_email).presence
        raise KeyError, "credentials aws.from_email is not set" unless sender

        address = Mail::Address.new(sender)
        address.display_name = "#{name} via Seera"
        address.format
      end

      # The name on the user's account, else on their newest finished resume.
      def name
        @name ||= user.name.to_s.squish.presence || resume_name || user.email.to_s.split("@").first
      end

      def resume_name
        resume = ResumeBuilder::PublicApi.latest_complete(user)
        resume && ResumeBuilder::PublicApi.read(user, resume["id"])["complete_name"].to_s.squish.presence
      end

      def cv_filename
        base = name.parameterize(separator: "_", preserve_case: true).presence || "cv"
        "#{base}_CV.pdf"
      end

      def body
        ApplicationController.render(
          template: "job_applications/emails/application", layout: false, formats: [ :text ],
          locals: {
            name:, title: posting.title.to_s.squish, employer: posting.employer.name, summary: application.summary.to_s.strip,
            notice_period: NOTICE_LABELS.fetch(profile.notice_period, profile.notice_period.to_s.humanize),
            visa_status: VISA_LABELS.fetch(profile.visa_status, profile.visa_status.to_s.humanize),
            salary: profile.expected_salary_sar,
            phone: profile.phone, linkedin_url: profile.linkedin_url, email: user.email
          }
        )
      end

      # The message as sent. One over the proof cap (a large CV) is kept
      # without the attachment, so the record of what was sent still fits.
      def proof(mail)
        eml = mail.to_s
        return eml if eml.bytesize <= Document::MAX_BYTES["proof"]

        copy = build(attach: false)
        copy.message_id = mail.message_id
        copy.date = mail.date
        copy.header["X-Seera-Attachment-Omitted"] = cv_filename
        copy.to_s
      end
    end
  end
end
