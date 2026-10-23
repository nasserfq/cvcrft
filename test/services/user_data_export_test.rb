require "test_helper"

class UserDataExportTest < ActiveSupport::TestCase
  setup do
    stub_pdf_generation
    @user = User.create!(email: "export-svc-#{SecureRandom.hex(4)}@example.com", name: "Export Service",
                         password: "password123", password_confirmation: "password123")
  end

  test "includes every section and the policy version" do
    resume = create_test_resume(@user, title: "Service Resume", complete_name: "Export Service",
                                       email: "svc-#{SecureRandom.hex(4)}@example.com")
    resume.skills.create!(category: "technical", skill_names: [ "Ruby" ])
    chat = Coach::Chat.create!(user: @user, path: "scratch")
    chat.messages.create!(role: "user", content: "Hello coach")

    data = UserDataExport.new(@user).as_json

    expected = %w[user resumes cv_analyses cv_imports linkedin_imports cv_generations ai_translations
                  coach_chats credit_ledger_entries credit_purchases identities exported_at privacy_policy_version]
    assert_equal expected.sort, data.keys.sort
    assert_equal PrivacyPolicy::VERSION, data["privacy_policy_version"]
    assert_equal "Service Resume", data["resumes"].first["title"]
    assert_equal "technical", data["resumes"].first["skills"].first["category"]
    assert_equal "Hello coach", data["coach_chats"].first["messages"].first["content"]
  end

  test "never exports password fields or PDF blobs" do
    CvGeneration.create!(user: @user, status: "completed", ai_model: "test",
                         job_description: "A job description that is long enough for validation rules",
                         metadata: { "pdf_data" => "BLOB", "pdf_generated" => true })

    export = UserDataExport.new(@user)
    data = export.as_json

    assert_not data["user"].key?("encrypted_password")
    assert_not data["user"].key?("reset_password_token")
    assert_equal({ "pdf_generated" => true }, data["cv_generations"].first["metadata"])
    assert_not_includes export.to_json, "BLOB"
  end

  test "lists linked sign-in accounts" do
    @user.identities.create!(provider: "apple", uid: "apple-uid-1", email: "relay@privaterelay.appleid.com")

    identity = UserDataExport.new(@user).as_json["identities"].sole

    assert_equal %w[created_at email provider uid], identity.keys.sort
    assert_equal [ "apple", "apple-uid-1", "relay@privaterelay.appleid.com" ], identity.values_at("provider", "uid", "email")
  end

  test "filename carries the export date" do
    export = UserDataExport.new(@user, now: Time.zone.local(2026, 10, 19, 8))
    assert_equal "seera-data-2026-10-19.json", export.filename
  end
end
