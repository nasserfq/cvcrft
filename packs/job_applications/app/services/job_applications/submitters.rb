module JobApplications
  # The registry of submitters, one per channel or ATS. Each submitter class:
  #
  #   .questions(posting) -> [Question hash]  # read over HTTP before any browser starts
  #   #initialize(application, cv_pdf:)       # cv_pdf: the PDF bytes
  #   #call -> Result                          # calls application.mark_submit_clicked! just before Submit
  #
  # Question hash: {"id", "label", "type" (text|textarea|select|radio|checkbox|file|email|tel|url|number),
  #                 "options" => [], "required" => bool, "section" => "main"|"eeo"}
  module Submitters
    # outcome: :sent or :fallback. confirmation: {url:, text:, message_id:, error_code:}
    # (error_code, one of Application::ERROR_CODES, only on a fallback).
    Result = Data.define(:outcome, :proof_bytes, :proof_type, :confirmation) do
      def self.sent(proof_bytes: nil, proof_type: nil, **confirmation)
        new(outcome: :sent, proof_bytes:, proof_type:, confirmation:)
      end

      def self.fallback(error_code, proof_bytes: nil, proof_type: nil, **confirmation)
        new(outcome: :fallback, proof_bytes:, proof_type:, confirmation: confirmation.merge(error_code: error_code.to_s))
      end

      def sent? = outcome == :sent
      def error_code = confirmation[:error_code] || confirmation["error_code"]
    end

    # A failure before Submit was clicked, so trying again is safe.
    class Retryable < StandardError; end

    REGISTRY = {
      "greenhouse" => "JobApplications::Submitters::Greenhouse",
      "ashby" => "JobApplications::Submitters::Ashby",
      "lever" => "JobApplications::Submitters::Lever",
      "workable" => "JobApplications::Submitters::Workable",
      "email" => "JobApplications::Submitters::Email"
    }.freeze

    # The submitter class for an application, or nil (manual, or one not built yet).
    def self.for(application)
      name = case application.channel
      when "browser" then REGISTRY[application.posting.employer.ats]
      when "email" then REGISTRY["email"]
      end
      name&.safe_constantize
    end
  end
end
