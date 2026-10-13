require "test_helper"

# Renders each admin page through Administrate. Guards against the app's view
# overrides drifting from the installed gem's templates (administrate 1.0
# added a `filters` local that the old index override did not pass on).
class AdminPagesTest < ActionDispatch::IntegrationTest
  setup do
    @auth = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]) }
  end

  %w[users resumes cv_generations ai_translations skills work_experiences certifications educations languages].each do |name|
    test "#{name} index renders" do
      get "/admin/#{name}", headers: @auth
      assert_response :success
    end
  end

  test "admin root renders" do
    get "/admin", headers: @auth
    assert_response :success
  end

  test "user show, edit and new render" do
    user = users(:test_user)
    get "/admin/users/#{user.id}", headers: @auth
    assert_response :success
    get "/admin/users/#{user.id}/edit", headers: @auth
    assert_response :success
    get "/admin/users/new", headers: @auth
    assert_response :success
  end

  test "resume show renders" do
    get "/admin/resumes/#{users(:test_user).resumes.first.id}", headers: @auth
    assert_response :success
  end
end
