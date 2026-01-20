class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :send_otp, :verify_otp, :logout ]
  before_action :authenticate_user!, only: [ :logout ]

  def login
    # Show login form
  end

  def send_otp
    email = params[:email]&.strip&.downcase
    return_to = params[:return_to]

    unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      flash[:alert] = "يرجى إدخال بريد إلكتروني صحيح"
      redirect_to login_path(return_to: return_to) and return
    end

    begin
      # Generate OTP
      otp_verification = OtpVerification.generate_for(email)

      # Send email via Sidekiq background job
      SendOtpEmailJob.perform_later(email, otp_verification.otp_code)

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
    return_to = params[:return_to]

    unless email.present? && otp_code.present?
      flash[:alert] = "البريد الإلكتروني ورمز التحقق مطلوبان"
      redirect_to login_path(return_to: return_to) and return
    end

    # Find valid OTP
    otp_verification = OtpVerification.valid.find_by(email: email, otp_code: otp_code)

    unless otp_verification
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

      # Verify the OTP
      if otp_verification.verify!(otp_code)
        # Sign in the user
        Rails.logger.info "About to sign in user: #{user.email} (ID: #{user.id})"
        sign_in(:user, user)
        Rails.logger.info "User signed in successfully. Session: #{session.inspect}"
        Rails.logger.info "Current user after sign_in: #{current_user&.email} (ID: #{current_user&.id})"
        Rails.logger.info "Warden user key: #{session['warden.user.user.key']}"

        # Track login event in PostHog
        identify_user(user)
        track_event("user_logged_in", { login_method: "otp" })

        flash[:notice] = "تم تسجيل الدخول بنجاح!"

        # Redirect to the intended destination or CV builder page
        if return_to.present? && return_to.start_with?("/")
          redirect_to return_to
        else
          redirect_to new_resume_path
        end
      else
        flash[:alert] = "رمز التحقق غير صحيح"
        redirect_to login_path(otp_sent: "true", email: email, return_to: return_to)
      end
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
end
