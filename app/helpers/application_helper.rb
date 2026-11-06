module ApplicationHelper
  SITE_URL = "https://cvcrft.com".freeze

  def random_coupon_code_placeholder
    SecureRandom.alphanumeric(8).upcase
  end

  # Where "build my CV" goes: straight to login for visitors, so crawlers
  # and people never take the extra /resumes/new -> /login redirect.
  def build_cv_path
    user_signed_in? ? new_resume_path : login_path(return_to: new_resume_path)
  end

  # Absolute URL of a public page in one locale. Arabic is the default and
  # lives at the bare URL; English is the same path with ?locale=en.
  def seo_url(path = request.path, locale: I18n.locale)
    url = "#{SITE_URL}#{path}"
    locale.to_s == "en" ? "#{url}?locale=en" : url
  end
end
