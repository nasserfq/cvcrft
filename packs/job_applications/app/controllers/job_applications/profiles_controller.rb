module JobApplications
  # The six setup answers and the consent, then the On / Paused / Off switch.
  # Turning it off withdraws consent, so turning it on again goes back through setup.
  class ProfilesController < BaseController
    include UserRateLimit

    FIELDS = %i[nationality visa_status notice_period expected_salary_sar phone linkedin_url].freeze

    rate_limit_per_user to: 30, within: 1.minute, only: %i[update sending], name: "seera-apply-profile"

    def edit
      @profile = Profile.find_by(user: current_user) || new_profile
    end

    def update
      @profile = Profile.find_or_initialize_by(user: current_user)
      @profile.assign_attributes(profile_params)
      @consent_missing = params[:consent] != "1"

      if @profile.valid? && !@consent_missing
        save_with_consent
        redirect_to my_jobs_root_path, notice: t("seera_apply.flash.saved")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def sending
      profile = Profile.find_by(user: current_user)
      state = params[:state].to_s
      return head(:bad_request) unless Profile::STATES.include?(state)
      return redirect_to(my_jobs_setup_path) if profile.nil? || (state != "off" && !profile.consented?)

      case state
      when "on" then profile.update!(state: "on")
      when "paused" then profile.pause!
      when "off" then profile.turn_off!
      end
      redirect_to my_jobs_root_path
    end

    private

    # Consent is recorded the first time (or again after a withdrawal); a
    # later edit keeps the current state, so a paused switch stays paused.
    def save_with_consent
      Profile.transaction do
        @profile.save!
        @profile.give_consent! unless @profile.consented?
      end
    end

    def profile_params
      attrs = params.fetch(:profile, {}).permit(*FIELDS).to_h.transform_values { |value| value.to_s.strip }
      attrs["expected_salary_sar"] = attrs["expected_salary_sar"].presence&.delete(",")
      attrs
    end

    # Starts the phone from the newest CV when it already fits the format.
    def new_profile
      profile = Profile.new(user: current_user)
      resume = ResumeBuilder::PublicApi.latest_complete(current_user)
      phone = resume && ResumeBuilder::PublicApi.read(current_user, resume["id"])["phone_number"].to_s.strip
      profile.phone = phone if phone&.match?(Profile::PHONE_FORMAT)
      profile
    end
  end
end
