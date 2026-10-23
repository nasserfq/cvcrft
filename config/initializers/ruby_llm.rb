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

  # The model a reply is regenerated on when Jev judges the cheap one not
  # good enough. Unset, failing replies are kept.
  def self.strong
    ENV["AI_STRONG_MODEL"].presence
  end

  # Opens a chat on the configured provider. `temperature` and `max_tokens`
  # are the only things the five callers ever varied.
  def self.chat(temperature: 0.7, max_tokens: nil, model: default)
    chat = RubyLLM.chat(model: model, provider: provider)
    chat = chat.with_temperature(temperature) if temperature
    chat = chat.with_max_output_tokens(max_tokens) if max_tokens
    chat
  end

  # One completion. Returns the RubyLLM::Message, so callers get both
  # `.content` (the text, which they parse as JSON) and `.tokens` (total
  # usage, which two of them persist). Given a block, the reply streams: the
  # block gets each RubyLLM::Chunk (`chunk.content` is the new text) and the
  # full message is still returned at the end.
  #
  # With `check:`, a yes/no question about the reply, Jev judges the cheap
  # model's answer and a failing one is regenerated once on the strong model.
  def self.complete(system:, user:, temperature: 0.7, max_tokens: nil, check: nil, &block)
    reply = ask(system, user, temperature, max_tokens, default, &block)
    return reply unless check && strong && passes?(check, user, reply.content) == false

    Rails.logger.info("[AiModel] Jev rejected #{default} reply, regenerating on #{strong}")
    ask(system, user, temperature, max_tokens, strong)
  end

  def self.ask(system, user, temperature, max_tokens, model, &block)
    chat(temperature: temperature, max_tokens: max_tokens, model: model)
      .with_instructions(system.to_s)
      .ask(user.to_s, &block)
  end

  # Jev's verdict on a reply: true or false, or nil when Jev isn't configured
  # or fails, in which case the reply is kept.
  def self.passes?(question, input, output)
    return nil if RubyLLM.config.typesafe_api_key.blank?

    judgment = RubyLLM.judge({ input: redact(input), output: redact(output) },
                             questions: { good: { type: :probability, instructions: question } },
                             model: "jev-latest", provider: :typesafe)
    judgment[:good].probability.to_f >= 0.5
  rescue RubyLLM::Error, Faraday::Error => e
    Sentry.capture_exception(e, tags: { feature: "ai_check" })
    nil
  end

  # Emails and phone numbers never leave for Jev, as the coach's judge does.
  def self.redact(text)
    text.to_s.gsub(/[\w.+-]+@[\w-]+(\.[\w-]+)+/, "[email]").gsub(/(?:\+|00)\d[\d\s-]{7,}\d|\b05\d{8}\b/, "[phone]")
  end

  # The JSON inside a reply. Claude fences it in ```json ... ```; gpt-4.1-mini
  # sent it bare. A reply that hits max_tokens loses its closing fence, so
  # when there is no full pair each fence is stripped on its own.
  def self.json_body(content)
    text = content.to_s.strip
    if (fenced = text.match(/```(?:json)?\s*(.*?)\s*```/m))
      return fenced[1]
    end

    text.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
  end

  # `message.tokens` is a RubyLLM::Tokens value object with no #total; the
  # tokens_used columns want a plain integer.
  def self.token_count(message)
    t = message.tokens
    return nil if t.nil?

    t.input.to_i + t.output.to_i
  end
end
