module JobApplications
  # Sends one queued application through Sender. A browser send first takes
  # the single Chromium slot; when it is busy the job tries again in a
  # minute. No ActiveJob retry: a send after the click must never repeat.
  class SendJob < ApplicationJob
    queue_as :apply_browser
    sidekiq_options retry: false

    def perform(application_id)
      application = Application.find_by(id: application_id)
      return unless application&.status == "queued"
      return unless JobApplications.enabled_for?(application.user)
      return Sender.new(application).call unless application.channel == "browser"

      token = BrowserSlot.acquire
      return self.class.set(wait: 1.minute).perform_later(application_id) unless token

      begin
        Sender.new(application).call
      ensure
        BrowserSlot.release(token)
      end
    end
  end
end
