# Where to send a user after login: shared by the email-code and social
# sign-in controllers.
module LoginRedirect
  private

  # Only same-site paths: "/x" is fine, "//host" and "/\\host" are not.
  def safe_return_to(path)
    path if path.is_a?(String) && path.match?(%r{\A/(?![/\\])})
  end
end
