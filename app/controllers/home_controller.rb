class HomeController < ApplicationController
  layout false, only: [ :index ]

  helper_method :landing_cached?, :landing_cache_key, :users_count

  def index
    # Show signout notification if user just signed out
    if params[:signed_out] == "true"
      flash.now[:notice] = "تم تسجيل الخروج بنجاح"
    end
  end

  private

  # Logged-out visitors all see the same landing, so its static parts are
  # served from the cache. The CSRF tags, consent banner and header (its
  # language switch carries a per-session token) render on every request.
  def landing_cached?
    !user_signed_in? && flash.empty?
  end

  # The deploy version covers translation and asset changes, which the
  # template digest the cache helper adds does not see; the year is in the footer.
  def landing_cache_key(part)
    [ "home", part, I18n.locale, Time.current.year, ENV["KAMAL_VERSION"] ]
  end

  # User count for social proof. Read lazily so a cached landing skips it.
  def users_count
    @users_count ||= Rails.cache.fetch("home/users_count", expires_in: 10.minutes) { User.count }
  end
end
