# Unified LLM client.
#
# Replaces five hand-rolled Net::HTTP copies of the same Azure OpenAI call
# (one per AI job), each of which hardcoded the endpoint and disabled TLS
# verification.
#
# Provider and model are environment-driven so moving to Bedrock is a config
# change rather than another five-file edit. Bedrock needs an IAM access key
# pair — RubyLLM signs with SigV4 and does not accept the ABSK bearer-token
# style Bedrock API key, despite `bedrock_api_key` being named as it is.

RubyLLM.configure do |config|
  # Azure OpenAI — the current provider.
  config.azure_api_base = ENV.fetch("AZURE_OPENAI_BASE", "https://craftcv.openai.azure.com")
  config.azure_api_key  = Rails.application.credentials.dig(:azure, :openai_api_key) ||
                          ENV["AZURE_OPENAI_API_KEY"]

  # Amazon Bedrock — inactive until AI_PROVIDER=bedrock and IAM keys are set.
  config.bedrock_api_key    = ENV["AWS_ACCESS_KEY_ID"]
  config.bedrock_secret_key = ENV["AWS_SECRET_ACCESS_KEY"]
  config.bedrock_region     = ENV.fetch("AWS_REGION", "us-east-1")

  # TypeSafe's Jev judges the coach's CVs; without a key Coach::Judge uses Haiku.
  config.typesafe_api_key = ENV["JEV_API_KEY"]

  config.request_timeout = ENV.fetch("AI_TIMEOUT", 120).to_i
end

module AiModel
  # :azure today; :bedrock once IAM credentials exist.
  def self.provider
    ENV.fetch("AI_PROVIDER", "azure").to_sym
  end

  # On Azure this is the deployment name; on Bedrock, the model id.
  def self.default
    ENV.fetch("AI_MODEL", "gpt-4.1-mini")
  end

  # Opens a chat on the configured provider. `temperature` and `max_tokens`
  # are the only things the five callers ever varied.
  def self.chat(temperature: 0.7, max_tokens: nil)
    chat = RubyLLM.chat(model: default, provider: provider)
    chat = chat.with_temperature(temperature) if temperature
    chat = chat.with_max_output_tokens(max_tokens) if max_tokens
    chat
  end

  # One completion. Returns the RubyLLM::Message, so callers get both
  # `.content` (the text, which they parse as JSON) and `.tokens` (total
  # usage, which two of them persist).
  def self.complete(system:, user:, temperature: 0.7, max_tokens: nil)
    chat(temperature: temperature, max_tokens: max_tokens)
      .with_instructions(system.to_s)
      .ask(user.to_s)
  end

  # `message.tokens` is a RubyLLM::Tokens value object with no #total; the
  # tokens_used columns want a plain integer.
  def self.token_count(message)
    t = message.tokens
    return nil if t.nil?

    t.input.to_i + t.output.to_i
  end
end
