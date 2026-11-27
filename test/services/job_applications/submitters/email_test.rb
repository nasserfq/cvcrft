require "test_helper"
require_relative "../../../support/seera_apply_helper"

class JobApplications::Submitters::EmailTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  FROM = "hello@cvcrft.com".freeze

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    Rails.application.credentials.stubs(:dig).with(:aws, :from_email).returns(FROM)
    @profile = create_profile(@user, visa_status: "iqama_transferable", expected_salary_sar: 25_000)
    posting = create_posting(create_employer(name: "Acme"), title: "Product Manager", apply_email: "jobs@acme.sa")
    @app = create_application(@user, posting:, channel: "email", summary: "Eight years shipping B2B products.")
    add_cv_pdf(@app)
    @sent = []
    @ses = Object.new
    sent = @sent
    @ses.define_singleton_method(:send_raw) do |mail|
      sent << Mail.new(mail.to_s)
      "ses-message-1"
    end
    AmazonSesService.stubs(:new).returns(@ses)
  end

  teardown { ENV.delete("BILLING_ENABLED") }

  test "has no form questions" do
    assert_equal [], JobApplications::Submitters::Email.questions(@app.posting)
  end

  test "Sender emails the employer from Seera with the user's name, Cc and Reply-To the user, and keeps the proof" do
    JobApplications::Sender.new(@app).call
    @app.reload
    mail = @sent.sole

    assert_equal [ "jobs@acme.sa" ], mail.to
    assert_equal [ @user.email ], mail.cc
    assert_equal [ @user.email ], mail.reply_to
    assert_equal [ FROM ], mail.from
    assert_equal "User One via Seera", mail[:from].display_names.sole
    assert_equal "Application: Product Manager – User One", mail.subject

    pdf = mail.attachments.sole
    assert_equal "application/pdf", pdf.mime_type
    assert_equal "User_One_CV.pdf", pdf.filename
    assert_equal "%PDF-1.4 tailored", pdf.decoded

    body = mail.text_part.decoded
    assert_includes body, "Eight years shipping B2B products."
    assert_includes body, "Notice period: One month"
    assert_includes body, "Work status: Iqama holder, transferable"
    assert_includes body, "Expected salary: SAR 25,000 per month"
    assert_includes body, "Phone: +966 500000000"
    assert_includes body, "LinkedIn: https://www.linkedin.com/in/sara"
    assert_no_match(/\p{Arabic}/, body)

    assert_equal "sent", @app.status
    assert_equal "ses-message-1", @app.confirmation["message_id"]
    assert @app.submit_clicked_at
    assert_equal "message/rfc822", @app.proof.content_type
    assert_match(/\.eml\z/, @app.proof.filename)
    assert_includes @app.proof.data, "To: jobs@acme.sa"
    assert_equal "sent", JobApplications::Disclosure.find_by!(application_id: @app.id).outcome
  end

  test "no salary line when none is given" do
    @profile.update!(expected_salary_sar: nil)
    JobApplications::Sender.new(@app).call

    assert_not_includes @sent.sole.text_part.decoded, "Expected salary"
  end

  test "an SES error is retried: the row goes back to queued and nothing counts as clicked" do
    @ses.define_singleton_method(:send_raw) { |_mail| raise Aws::SES::Errors::Throttling.new(nil, "Rate exceeded") }

    JobApplications::Sender.new(@app).call
    @app.reload

    assert_equal [ "queued", 1 ], [ @app.status, @app.attempts ]
    assert_nil @app.submit_clicked_at
    assert_nil @app.charge
  end

  test "a posting without an address falls back and sends nothing" do
    @app.posting.update_columns(apply_email: nil)

    result = JobApplications::Submitters::Email.new(@app, cv_pdf: @app.cv_pdf.data).call

    assert_equal [ :fallback, "unsupported" ], [ result.outcome, result.error_code ]
    assert_empty @sent
  end

  test "a proof over the cap is kept without the attachment" do
    big = "%PDF-1.4 " + SecureRandom.random_bytes(900.kilobytes)
    @app.cv_pdf.update!(data: big)

    JobApplications::Sender.new(@app).call
    @app.reload

    assert_equal "sent", @app.status
    proof = Mail.new(@app.proof.data)
    assert_empty proof.attachments
    assert_equal "User_One_CV.pdf", proof["X-Seera-Attachment-Omitted"].value
    assert_equal @sent.sole.message_id, proof.message_id
  end
end
