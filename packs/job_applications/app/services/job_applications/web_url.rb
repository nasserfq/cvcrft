module JobApplications
  # Feed URLs end up in an href, so only absolute http(s) links with a host count.
  module WebUrl
    module_function

    def valid?(value)
      uri = URI.parse(value.to_s.strip)
      %w[http https].include?(uri.scheme&.downcase) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end
end
