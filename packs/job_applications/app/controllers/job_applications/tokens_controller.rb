module JobApplications
  # Pairing tokens for the browser extension. The raw token is shown once.
  class TokensController < BaseController
    def create
      _token, raw = Token.issue!(current_user)
      flash[:auto_apply_token] = raw
      redirect_to auto_apply_root_path(anchor: "extension"), notice: t("auto_apply.flash.token_created")
    end

    def destroy
      Token.where(user: current_user).active.update_all(revoked_at: Time.current, updated_at: Time.current)
      redirect_to auto_apply_root_path(anchor: "extension"), notice: t("auto_apply.flash.token_revoked")
    end
  end
end
