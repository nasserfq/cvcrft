require "aws-sdk-ses"

class AmazonSesService
  def initialize
    @client = Aws::SES::Client.new(
      region: Rails.application.credentials.aws[:region] || "us-east-1",
      access_key_id: Rails.application.credentials.aws[:access_key_id],
      secret_access_key: Rails.application.credentials.aws[:secret_access_key],
      # Disable SSL verification to bypass macOS CRL check issues
      ssl_verify_peer: false
    )
  end

  def send_email(to:, subject:, body:)
    @client.send_email({
      source: Rails.application.credentials.aws[:from_email],
      destination: {
        to_addresses: [ to ]
      },
      message: {
        subject: {
          data: subject,
          charset: "UTF-8"
        },
        body: {
          html: {
            data: body,
            charset: "UTF-8"
          }
        }
      }
    })
  rescue Aws::SES::Errors::ServiceError => e
    Rails.logger.error "Amazon SES Error: #{e.message}"
    raise e
  end
end
