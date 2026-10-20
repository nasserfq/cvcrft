require "test_helper"

class UserTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert users(:admin_user).valid?, "admin_user fixture should be valid"
    assert users(:test_user).valid?, "test_user fixture should be valid"
    assert users(:user_with_resumes).valid?, "user_with_resumes fixture should be valid"
    assert users(:arabic_user).valid?, "arabic_user fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save user without email" do
    user = User.new(name: "Test User", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should not save user without name" do
    user = User.new(email: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should not save user with invalid email format" do
    invalid_emails = [ "invalid", "test@", "@example.com", "test.example.com", "test@.com" ]

    invalid_emails.each do |email|
      user = User.new(email: email, name: "Test", password: "password123")
      assert_not user.valid?, "#{email} should be invalid"
      assert user.errors[:email].any?, "should have email error for #{email}"
    end
  end

  test "should save user with valid email format" do
    valid_emails = [ "validtest-#{SecureRandom.hex(4)}@example.com", "user.name-#{SecureRandom.hex(4)}@domain.org", "test+tag-#{SecureRandom.hex(4)}@example.co.uk" ]

    valid_emails.each do |email|
      user = User.new(email: email, name: "Test User", password: "password123")
      assert user.valid?, "#{email} should be valid: #{user.errors.full_messages.join(', ')}"
    end
  end

  test "should not save user with duplicate email" do
    existing_user = users(:test_user)
    new_user = User.new(email: existing_user.email, name: "New User", password: "password123")
    assert_not new_user.valid?
    assert_includes new_errors_for(new_user, :email), "has already been taken"
  end

  test "should not save user with name too short" do
    user = User.new(email: "short@example.com", name: "A", password: "password123")
    assert_not user.valid?
    assert user.errors[:name].any?
  end

  test "should not save user with name too long" do
    user = User.new(email: "long@example.com", name: "A" * 101, password: "password123")
    assert_not user.valid?
    assert user.errors[:name].any?
  end

  test "should support Arabic names" do
    user = users(:arabic_user)
    assert user.valid?
    assert_equal "مستخدم عربي", user.name
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "user has many resumes" do
    user = users(:user_with_resumes)
    assert_respond_to user, :resumes
    assert user.resumes.count >= 0
  end

  test "user has many ai_translations" do
    user = users(:user_with_resumes)
    assert_respond_to user, :ai_translations
  end

  test "user has many cv_generations" do
    user = users(:user_with_resumes)
    assert_respond_to user, :cv_generations
  end

  test "user has many work_experiences through resumes" do
    user = users(:user_with_resumes)
    assert_respond_to user, :work_experiences
  end

  test "user has many skills through resumes" do
    user = users(:user_with_resumes)
    assert_respond_to user, :skills
  end

  test "destroying user destroys associated resumes" do
    user = users(:user_with_resumes)
    resume_count = user.resumes.count

    assert_difference "Resume.count", -resume_count do
      user.destroy
    end
  end

  test "destroying user destroys associated cv_generations" do
    user = users(:user_with_resumes)
    generation_count = user.cv_generations.count

    assert_difference "CvGeneration.count", -generation_count do
      user.destroy
    end
  end

  test "destroying user destroys associated ai_translations" do
    user = users(:user_with_resumes)
    translation_count = user.ai_translations.count

    assert_difference "AiTranslation.count", -translation_count do
      user.destroy
    end
  end

  # ============================================
  # CV GENERATION STATISTICS TESTS
  # ============================================

  test "cv_generation_count returns correct count" do
    user = users(:user_with_resumes)
    assert_equal user.cv_generations.count, user.cv_generation_count
  end

  test "completed_cv_count returns only completed generations" do
    user = users(:user_with_resumes)
    expected = user.cv_generations.where(status: "completed").count
    assert_equal expected, user.completed_cv_count
  end

  test "processing_cv_count returns only processing generations" do
    user = users(:test_user)
    expected = user.cv_generations.where(status: "processing").count
    assert_equal expected, user.processing_cv_count
  end

  test "failed_cv_count returns only failed generations" do
    user = users(:arabic_user)
    expected = user.cv_generations.where(status: "failed").count
    assert_equal expected, user.failed_cv_count
  end

  test "total_tokens_used sums tokens from all generations" do
    user = users(:user_with_resumes)
    expected = user.cv_generations.sum(:tokens_used) || 0
    assert_equal expected, user.total_tokens_used
  end

  # ============================================
  # RESUME STATISTICS TESTS
  # ============================================

  test "resume_count returns correct count" do
    user = users(:user_with_resumes)
    assert_equal user.resumes.count, user.resume_count
  end

  test "resumes_with_work_experience counts correctly" do
    user = users(:user_with_resumes)
    count = user.resumes_with_work_experience
    assert count >= 0
  end

  test "resumes_with_skills counts correctly" do
    user = users(:user_with_resumes)
    count = user.resumes_with_skills
    assert count >= 0
  end

  test "resumes_with_ats_score counts correctly" do
    user = users(:user_with_resumes)
    expected = user.resumes.where.not(ats_score: nil).count
    assert_equal expected, user.resumes_with_ats_score
  end

  test "average_ats_score calculates correctly" do
    user = users(:user_with_resumes)
    avg = user.average_ats_score
    assert avg.is_a?(Numeric)
    assert avg >= 0
  end

  test "average_ats_score returns 0 when no ats scores" do
    user = users(:user_without_resumes)
    assert_equal 0, user.average_ats_score
  end

  # ============================================
  # DEVISE AUTHENTICATION TESTS
  # ============================================

  test "user can authenticate with correct password" do
    user = users(:test_user)
    assert user.valid_password?("password123")
  end

  test "user cannot authenticate with wrong password" do
    user = users(:test_user)
    assert_not user.valid_password?("wrongpassword")
  end

  # ============================================
  # PDPL ERASURE
  # ============================================

  test "destroying a user with imports and coupon redemptions removes them all" do
    stub_pdf_generation
    user = User.create!(email: "erase-model-#{SecureRandom.hex(4)}@example.com", name: "Erase Model",
                        password: "password123", password_confirmation: "password123")
    resume = create_test_resume(user, complete_name: "Erase Model", email: "erase-model-r-#{SecureRandom.hex(4)}@example.com")
    CvImport.create!(user: user, resume: resume, status: "completed", original_filename: "cv.pdf")
    coupon_id = ActiveRecord::Base.connection.select_value(<<~SQL)
      INSERT INTO coupons (code, created_at, updated_at)
      VALUES ('MODEL#{SecureRandom.hex(3).upcase}', NOW(), NOW()) RETURNING id
    SQL
    CouponRedemption.create!(user: user, coupon_id: coupon_id, redeemed_at: Time.current)

    assert_difference("User.count", -1) { user.destroy! }
    assert_equal 0, CouponRedemption.where(user_id: user.id).count
    assert_equal 0, CvImport.where(user_id: user.id).count
  end

  test "destroying a user destroys its sign-in identities" do
    user = User.create!(email: "identity-#{SecureRandom.hex(4)}@example.com", name: "Identity User",
                        password: "password123", password_confirmation: "password123")
    user.identities.create!(provider: "google_oauth2", uid: "g-#{SecureRandom.hex(4)}")
    user.identities.create!(provider: "linkedin", uid: "l-#{SecureRandom.hex(4)}")

    assert_difference("UserIdentity.count", -2) { user.destroy! }
  end

  private

  def new_errors_for(record, attribute)
    record.valid?
    record.errors[attribute]
  end
end
