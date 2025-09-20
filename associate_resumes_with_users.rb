#!/usr/bin/env ruby

# Script to associate existing resumes with users based on email addresses
# Run this with: rails runner associate_resumes_with_users.rb

puts "=== ASSOCIATING RESUMES WITH USERS ==="

User.all.each do |user|
  puts "\nProcessing user: #{user.email} (ID: #{user.id})"
  
  # Find resumes with matching email that don't have a user_id
  resumes = Resume.where(email: user.email, user_id: nil)
  puts "Found #{resumes.count} resumes for #{user.email}"
  
  if resumes.any?
    # Associate them with the user
    updated_count = resumes.update_all(user_id: user.id)
    puts "✅ Associated #{updated_count} resumes with user #{user.id}"
  else
    puts "ℹ️  No resumes found for #{user.email}"
  end
end

puts "\n=== FINAL VERIFICATION ==="
User.all.each do |user|
  puts "User: #{user.email} (ID: #{user.id}) - Resumes: #{user.resumes.count}"
end

puts "\n=== RESUMES WITHOUT USERS ==="
orphaned_resumes = Resume.where(user_id: nil)
puts "Orphaned resumes: #{orphaned_resumes.count}"
if orphaned_resumes.any?
  orphaned_resumes.each do |resume|
    puts "  - ID: #{resume.id}, Name: #{resume.complete_name}, Email: #{resume.email}"
  end
end

puts "\n✅ Script completed!"
