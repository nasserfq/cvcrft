class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :logout ]
  before_action :authenticate_user!, only: [ :logout ]
  before_action :redirect_if_authenticated, only: [ :login ]
  layout false, only: [ :login ]

  # Throttle code requests and guesses. Per IP for both, and per address for
  # sending so nobody can flood one inbox or burn a victim's pending code.
  rate_limit to: 5, within: 10.minutes, only: :send_otp, name: "otp-send-ip",
             with: -> { redirect_to login_path, alert: "محاولات كثيرة. يرجى المحاولة بعد قليل." }
  rate_limit to: 3, within: 10.minutes, only: :send_otp, name: "otp-send-email",
             by: -> { params[:email].to_s.strip.downcase },
             with: -> { redirect_to login_path(otp_sent: "true", email: params[:email]), alert: "تم إرسال رمز مؤخراً. يرجى التحقق من بريدك أو المحاولة بعد قليل." }
  rate_limit to: 20, within: 10.minutes, only: :verify_otp, name: "otp-verify-ip",
             with: -> { redirect_to login_path, alert: "محاولات كثيرة. يرجى المحاولة بعد قليل." }

  # An expired or missing form token (e.g. a login page left open) sends the
  # user back to a fresh login page instead of a 422.
  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_to login_path, alert: "انتهت صلاحية الصفحة. يرجى المحاولة مرة أخرى."
  end

  def login
    # Show login form (only for unauthenticated users)
  end

  def send_otp
    email = params[:email]&.strip&.downcase
    return_to = params[:return_to]

    unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      flash[:alert] = "يرجى إدخال بريد إلكتروني صحيح"
      redirect_to login_path(return_to: return_to) and return
    end

    # PDPL: no code is sent until the user accepts the privacy policy and terms.
    unless privacy_consent_given?
      flash[:alert] = t("pdpl_consent.required")
      redirect_to login_path(return_to: return_to) and return
    end

    begin
      # Generate OTP
      otp_verification = OtpVerification.generate_for(email)

      # Send email via Sidekiq background job
      SendOtpEmailJob.perform_later(otp_verification.id)

      flash[:notice] = "تم إرسال رمز التحقق إلى بريدك الإلكتروني"
      redirect_to login_path(otp_sent: "true", email: email, return_to: return_to)
    rescue => e
      Rails.logger.error "OTP Send Error: #{e.message}"
      flash[:alert] = "فشل في إرسال رمز التحقق. يرجى المحاولة مرة أخرى."
      redirect_to login_path(return_to: return_to)
    end
  end

  def verify_otp
    email = params[:email]&.strip&.downcase
    otp_code = params[:otp_code]&.strip
    return_to = params[:return_to].presence || session.delete(:user_return_to)

    unless email.present? && otp_code.present?
      flash[:alert] = "البريد الإلكتروني ورمز التحقق مطلوبان"
      redirect_to login_path(return_to: return_to) and return
    end

    # Find the pending OTP for this email; verify! checks the code and counts
    # wrong guesses against it.
    otp_verification = OtpVerification.valid.where(email: email).order(created_at: :desc).first

    unless otp_verification&.verify!(otp_code)
      flash[:alert] = "رمز التحقق غير صحيح أو منتهي الصلاحية"
      redirect_to login_path(otp_sent: "true", email: email, return_to: return_to) and return
    end

    begin
      # Find or create user
      user = User.find_or_create_by(email: email) do |u|
        u.password = SecureRandom.hex(16) # Random password since we're using OTP
        u.password_confirmation = u.password
        u.name = email.split("@").first # Use email prefix as name
      end

      # Ensure user is saved
      user.save! if user.changed?
      record_privacy_consent(user)

      sign_in(:user, user)
      Rails.logger.info "User #{user.id} signed in"

      # Track login event in PostHog
      identify_user(user)
      track_event("user_logged_in", { login_method: "otp" })

      flash[:notice] = "تم تسجيل الدخول بنجاح!"

      # Redirect to the intended destination or CV builder page
      redirect_to safe_return_to(return_to) || new_resume_path
    rescue => e
      Rails.logger.error "OTP Verification Error: #{e.message}"
      flash[:alert] = "فشل في تسجيل الدخول. يرجى المحاولة مرة أخرى."
      redirect_to login_path(return_to: return_to)
    end
  end

  def logout
    track_event("user_logged_out")
    sign_out(current_user)
    redirect_to root_path(signed_out: "true")
  end

  def status
    if user_signed_in?
      render json: {
        authenticated: true,
        user: {
          id: current_user.id,
          email: current_user.email,
          created_at: current_user.created_at
        }
      }
    else
      render json: { authenticated: false }
    end
  end

  private

  def privacy_consent_given?
    params[:privacy_consent] == "1"
  end

  # The OTP form carries the email form's consent. Links already sitting in
  # mailboxes have no flag: they still log in, they just record nothing.
  def record_privacy_consent(user)
    return unless privacy_consent_given?

    user.update_columns(privacy_accepted_at: Time.current, privacy_policy_version: PrivacyPolicy::VERSION)
  end

  # Only same-site paths: "/x" is fine, "//host" and "/\\host" are not.
  def safe_return_to(path)
    path if path.is_a?(String) && path.match?(%r{\A/(?![/\\])})
  end

  def redirect_if_authenticated
    if user_signed_in?
      # If user is already logged in, redirect to return_to or home
      return_to = params[:return_to].presence || session.delete(:user_return_to)
      redirect_to safe_return_to(return_to) || root_path
    end
  end
end
