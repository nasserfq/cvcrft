# Background CV PDF Generation Implementation

## Overview

This enhancement moves the CV Builder's PDF generation process from synchronous controller processing to an asynchronous background job using Sidekiq. This offers several benefits:

1. Faster response times for users
2. Better scalability under load
3. More resilient PDF generation that won't fail due to request timeouts
4. Improved user experience with status updates

## Components Added/Modified

1. **New Job Class**: `CvBuilderPdfJob` in `app/jobs/cv_builder_pdf_job.rb`

   - Handles PDF generation asynchronously
   - Supports both existing resumes and temporary form data
   - Stores generated PDFs for later retrieval

2. **Controller Changes**: `Api::TranslationsController`

   - Modified `export_pdf` to enqueue background job
   - Added new `pdf_status` endpoint to check job status
   - Added support for downloading completed PDFs

3. **Frontend Updates**: `MultiStepResumeForm.jsx`

   - Added status polling mechanism
   - Enhanced UI feedback during PDF generation

4. **Routes**: Added new endpoint
   - Added `pdf_status` route for checking job status

## How It Works

1. User clicks "إنشاء السيرة الذاتية ATS و تحميلها" (Create ATS CV and Download it)
2. The request is sent to the server which:
   - Creates a Sidekiq background job
   - Returns job ID and token to frontend
   - Responds immediately (no waiting)
3. Frontend starts polling for job status every 2 seconds
4. When job completes:
   - PDF is stored in Redis (temporary) or on the resume record
   - Status endpoint returns download URL
   - Frontend triggers automatic download

## Testing Instructions

1. **Start Sidekiq Worker**:

   ```bash
   bundle exec sidekiq -C config/sidekiq.yml
   ```

2. **Testing New Resume**:

   - Fill in resume form fields
   - Click "إنشاء السيرة الذاتية ATS و تحميلها"
   - Observe status messages and download starting automatically

3. **Testing Existing Resume**:

   - Navigate to an existing resume
   - Click "إنشاء السيرة الذاتية ATS و تحميلها"
   - PDF should be generated in the background and download automatically

4. **Monitoring Jobs**:
   - Check Sidekiq dashboard at `/sidekiq`
   - Monitor job processing, retries, and errors

## Error Handling

- Job timeouts after 2 minutes
- Failed jobs retry up to 3 times
- Frontend shows appropriate error messages
- Temporary PDFs expire after 30 minutes to manage storage

## Future Improvements

1. WebSocket notifications instead of polling
2. Progress updates during generation
3. Queue priority based on user tier
4. PDF customization options before generation
