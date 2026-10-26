class HomeController < ApplicationController
  layout false, only: [ :index ]

  helper_method :landing_cached?, :landing_cache_key, :users_count, :edge_cacheable?

  def index
    # Show signout notification if user just signed out
    if params[:signed_out] == "true"
      flash.now[:notice] = "تم تسجيل الخروج بنجاح"
    end

    if edge_cacheable?
      # Cloudflare keeps this page for a minute (its cache rule only lets
      # through requests without these cookies), so it must not set any.
      request.session_options[:skip] = true
      expires_in 0, public: true, "s-maxage": 60
    end
  end

  private

  # A first visit: no session, no language picked, no query string. Every such
  # visitor gets the same Arabic landing, so Cloudflare can serve it.
  def edge_cacheable?
    return @edge_cacheable if defined?(@edge_cacheable)

    @edge_cacheable = request.query_parameters.empty? &&
      !cookies.key?(Rails.application.config.session_options[:key]) &&
      cookies[:locale].blank?
  end

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
