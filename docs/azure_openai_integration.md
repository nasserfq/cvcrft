# Azure OpenAI Integration with Sidekiq Background Jobs

This document explains how to use the Azure OpenAI integration for translating Arabic text to English in your Rails application.

## Setup

### 1. Environment Variables

Set this environment variable in your `.env` file:

```bash
AZURE_OPENAI_API_KEY="your_openai_api_key"
```

### 2. Rails Credentials (Alternative)

You can also store credentials in Rails encrypted credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Add this to your credentials:

```yaml
azure:
 openai_api_key: "your_openai_api_key"
 openai_endpoint: "https://craftcv.openai.azure.com"
 openai_deployment: "gpt-4.1-mini"
 openai_api_version: "2025-01-01-preview"
```

### 3. Authentication Method

This integration uses **API Key authentication** instead of OAuth2, which is simpler and more direct for Azure OpenAI services.

**Important:** Make sure your Azure OpenAI resource is configured to accept API key authentication.

### 4. Sidekiq Configuration

Ensure Sidekiq is running:

```bash
bundle exec sidekiq
```

## Usage

### Basic Translation

```ruby
# Initialize the service
service = CvGenerationService.new(user_id, resume_id)

# Translate Arabic text
result = service.translate_text("نص عربي للترجمة", {
  temperature: 0.7,
  top_p: 0.95,
  max_tokens: 1000
})

puts result
# => {
#      status: 'queued',
#      message: 'Translation job has been queued and will be processed in the background',
#      job_id: 'uuid-here'
#    }
```

### Translate Work Experience

```ruby
# Translate work experience description
result = service.translate_work_experience(
  work_experience_id,
  "وصف الوظيفة باللغة العربية",
  { temperature: 0.5 }
)
```

### Translate Professional Summary

```ruby
# Translate professional summary
result = service.translate_professional_summary(
  "ملخص مهني باللغة العربية",
  { max_tokens: 500 }
)
```

### Check Translation Status

```ruby
# Get translation status
status = service.get_translation_status(translation_id)
puts status[:status] # => 'completed', 'processing', 'failed', etc.
puts status[:english_text] # => Translated text when completed
```

### Get User Translations

```ruby
# Get all translations for a user
translations = service.get_user_translations(limit: 20)

translations.each do |translation|
  puts "ID: #{translation[:id]}"
  puts "Status: #{translation[:status]}"
  puts "Arabic: #{translation[:arabic_text]}"
  puts "English: #{translation[:english_text]}"
  puts "Quality: #{translation[:translation_quality]}"
  puts "Tokens: #{translation[:tokens_used]}"
  puts "---"
end
```

### Get Resume Translations

```ruby
# Get all translations for a specific resume
resume_translations = service.get_resume_translations(limit: 10)
```

### Retry Failed Translations

```ruby
# Retry a failed translation
result = service.retry_translation(translation_id)

if result[:error]
  puts "Error: #{result[:error]}"
else
  puts "Retrying: #{result[:message]}"
end
```

### Cancel Pending Translations

```ruby
# Cancel a processing translation
result = service.cancel_translation(translation_id)

if result[:error]
  puts "Error: #{result[:error]}"
else
  puts "Cancelled: #{result[:message]}"
end
```

### Get Statistics

```ruby
# Get translation statistics
stats = service.get_translation_stats

puts "Total translations: #{stats[:total_translations]}"
puts "Completed: #{stats[:completed]}"
puts "Failed: #{stats[:failed]}"
puts "Processing: #{stats[:processing]}"
puts "Total tokens used: #{stats[:total_tokens_used]}"
puts "Average quality: #{stats[:average_quality]}"
```

## Direct Job Usage

You can also use the job directly:

```ruby
# Enqueue translation job
AiTranslationJob.perform_async(
  "نص عربي للترجمة",
  user_id,
  resume_id,
  {
    temperature: 0.7,
    top_p: 0.95,
    max_tokens: 1000,
    work_experience_id: 123,
    professional_summary: false
  }
)
```

## Job Parameters

The `AiTranslationJob` accepts these parameters:

- `arabic_text` (String): The Arabic text to translate
- `user_id` (Integer): ID of the user requesting translation
- `resume_id` (Integer, optional): ID of the resume if applicable
- `options` (Hash, optional): Additional options

### Available Options

- `temperature` (Float): Controls randomness (0.0 to 1.0)
- `top_p` (Float): Controls diversity (0.0 to 1.0)
- `max_tokens` (Integer): Maximum tokens in response
- `work_experience_id` (Integer): ID of work experience to update
- `professional_summary` (Boolean): Whether this is a summary translation

## Response Format

The AI model returns responses in this JSON format:

```json
{
 "english_text": "Translated English text",
 "skills_extracted": [
  {
   "name": "skill name",
   "level": "beginner/intermediate/expert",
   "category": "technical/soft/domain"
  }
 ],
 "translation_notes": "Any important notes about the translation"
}
```

## Error Handling

The job includes comprehensive error handling:

- **Network errors**: Retries up to 3 times
- **API errors**: Logs detailed error information
- **Parsing errors**: Falls back to plain text if JSON parsing fails
- **Database errors**: Logs and updates translation status

## Monitoring

### Sidekiq Dashboard

Monitor job progress at `/sidekiq` (if configured):

```ruby
# config/routes.rb
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

### Logs

Check Rails logs for detailed information:

```bash
tail -f log/development.log | grep "AI Translation"
```

### Database

Monitor the `ai_translations` table for job status and results.

## Performance Considerations

- **Async processing**: All translations run in background
- **Retry logic**: Failed jobs retry automatically
- **Token tracking**: Monitor API usage and costs
- **Batch processing**: Consider batching multiple translations

## Security

- **API Key encryption**: Azure OpenAI API key is encrypted in Rails credentials
- **User isolation**: Users can only access their own translations
- **Input validation**: Sanitize Arabic text input
- **Rate limiting**: Consider implementing rate limiting for API calls
- **Secure storage**: API key is never exposed in logs or error messages
