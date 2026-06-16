namespace :resumes do
  desc "Remove duplicate unfinished draft resumes (keeps the most recently updated copy per duplicate group)"
  task dedupe_drafts: :environment do
    total_removed = 0
    users_processed = 0

    User.find_each do |user|
      removed = ResumeDraftDeduplicator.call(user)
      next if removed.zero?

      users_processed += 1
      total_removed += removed
      puts "User ##{user.id} (#{user.email}): removed #{removed} duplicate draft(s)"
    end

    puts "Done. Removed #{total_removed} duplicate draft(s) across #{users_processed} user(s)."
  end
end
