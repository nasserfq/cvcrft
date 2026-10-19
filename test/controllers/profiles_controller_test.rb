require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user

    # Stub PDF generation
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
  end

  test "should redirect to login when not authenticated" do
    sign_out @user
    get profile_url
    assert_response :redirect
  end

  test "should get show when authenticated" do
    get profile_url
    assert_response :success
  end

  test "should display user information" do
    get profile_url
    assert_response :success
    assert_select "body"
  end

  test "should display resume statistics" do
    # Create a resume for the user
    Resume.create!(
      user: @user,
      complete_name: "Test User",
      email: "profile-test-#{SecureRandom.hex(4)}@example.com",
      is_draft: false
    )

    get profile_url
    assert_response :success
  end

  test "should display limit information" do
    get profile_url
    assert_response :success
    # The page should show generation limits
    assert_select "body"
  end

  test "should delete user account" do
    # Create a fresh user for deletion test
    user_to_delete = User.create!(
      email: "delete-test-#{SecureRandom.hex(4)}@example.com",
      name: "Delete Test User",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user_to_delete

    assert_difference("User.count", -1) do
      delete profile_url
    end
    assert_redirected_to root_url
  end

  test "should destroy associated data when deleting account" do
    # Create a user with associated data
    user_to_delete = User.create!(
      email: "delete-data-#{SecureRandom.hex(4)}@example.com",
      name: "Delete Data Test User",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user_to_delete

    # Create associated resume
    Resume.create!(
      user: user_to_delete,
      complete_name: "User to Delete",
      email: "user-delete-#{SecureRandom.hex(4)}@example.com"
    )

    # Create associated cv_generation
    CvGeneration.create!(
      user: user_to_delete,
      job_description: "Test job description that is long enough to pass validation requirements",
      ai_model: "gpt-4",
      status: "completed"
    )

    delete profile_url

    assert_equal 0, Resume.where(user_id: user_to_delete.id).count
    assert_equal 0, CvGeneration.where(user_id: user_to_delete.id).count
  end

  test "export redirects to login when not authenticated" do
    sign_out @user
    get export_profile_url
    assert_response :redirect
  end

  test "export downloads the user's data as a JSON attachment" do
    resume = Resume.create!(user: @user, title: "Export Me Resume", complete_name: "Export User",
                            email: "export-#{SecureRandom.hex(4)}@example.com", is_draft: false)
    CvGeneration.create!(user: @user, resume: resume, status: "completed", ai_model: "test",
                         job_description: "A job description that is long enough for validation rules",
                         metadata: { "pdf_data" => "SECRETPDFBLOB", "pdf_generated" => true })

    travel_to Time.zone.local(2026, 10, 19, 12) do
      get export_profile_url
    end

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/seera-data-2026-10-19\.json/, response.headers["Content-Disposition"])
    assert_includes response.body, "Export Me Resume"
    assert_not_includes response.body, "encrypted_password"
    assert_not_includes response.body, "pdf_data"
    assert_not_includes response.body, "SECRETPDFBLOB"

    data = JSON.parse(response.body)
    assert_equal @user.email, data["user"]["email"]
    assert_equal PrivacyPolicy::VERSION, data["privacy_policy_version"]
  end

  test "destroy removes imports, coupon redemptions, OTPs and the stored redemption without PostHog PII" do
    CouponRedemptionStore.reset!
    user = User.create!(email: "erase-#{SecureRandom.hex(4)}@example.com", name: "Erase Me",
                        password: "password123", password_confirmation: "password123")
    resume = Resume.create!(user: user, complete_name: "Erase Me", email: "erase-resume-#{SecureRandom.hex(4)}@example.com")
    CvImport.create!(user: user, resume: resume, status: "completed", original_filename: "cv.pdf")
    LinkedinImport.create!(user: user, resume: resume, status: "completed", original_filename: "in.pdf")
    coupon_id = ActiveRecord::Base.connection.select_value(<<~SQL)
      INSERT INTO coupons (code, created_at, updated_at)
      VALUES ('ERASE#{SecureRandom.hex(3).upcase}', NOW(), NOW()) RETURNING id
    SQL
    CouponRedemption.create!(user: user, coupon_id: coupon_id, redeemed_at: Time.current)
    OtpVerification.create!(email: user.email, otp_code: "123456", expires_at: 10.minutes.from_now)
    code = CouponRegistry.all.first&.code
    CouponRedemptionStore.redeem!(user.id, code) if code

    sign_in user
    cookies[:analytics_consent] = "granted"
    PostHog.expects(:capture).never

    assert_difference("User.count", -1) do
      delete profile_url
    end

    assert_redirected_to root_url
    assert_equal 0, CvImport.where(user_id: user.id).count
    assert_equal 0, LinkedinImport.where(user_id: user.id).count
    assert_equal 0, CouponRedemption.where(user_id: user.id).count
    assert_equal 0, OtpVerification.where(email: user.email).count
    assert_equal 0, Resume.where(user_id: user.id).count
    assert_not CouponRedemptionStore.redeemed?(user.id, code) if code
  end
end
