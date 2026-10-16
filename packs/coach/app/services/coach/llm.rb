module Coach
  # The coach's only door to RubyLLM: providers and model names live here, and callers take it as `llm:`.
  module Llm
    PROVIDER = :bedrock
    MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")
    FAST_MODEL = ENV.fetch("COACH_FAST_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0")
    JUDGE_MODEL = "jev-latest"
    JUDGE_PROVIDER = :typesafe

    module_function

    def chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)

    def fast_chat = RubyLLM.chat(model: FAST_MODEL, provider: PROVIDER)

    def judge? = RubyLLM.config.typesafe_api_key.present?

    def judge(text, questions:) = RubyLLM.judge(text, questions:, model: JUDGE_MODEL, provider: JUDGE_PROVIDER)
  end
end
