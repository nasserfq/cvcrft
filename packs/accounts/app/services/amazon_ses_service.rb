require "aws-sdk-ses"

class AmazonSesService
  def initialize
    @client = Aws::SES::Client.new(
      region: Rails.application.credentials.aws[:region] || "us-east-1",
      access_key_id: Rails.application.credentials.aws[:access_key_id],
      secret_access_key: Rails.application.credentials.aws[:secret_access_key]
    )
  end

  # body is the HTML part; text, when given, is the plain-text alternative.
  def send_email(to:, subject:, body:, text: nil)
    message_body = { html: { data: body, charset: "UTF-8" } }
    message_body[:text] = { data: text, charset: "UTF-8" } if text.present?

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
        body: message_body
      }
    })
  rescue Aws::SES::Errors::ServiceError => e
    Rails.logger.error "Amazon SES Error: #{e.message}"
    raise e
  end
end
