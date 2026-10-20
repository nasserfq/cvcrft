require "test_helper"

# Destructive actions on the profile page must go through the confirm-delete
# Stimulus dialog (Turbo is not loaded, so data-turbo-confirm would do nothing).
class ProfileConfirmDeleteMarkupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user

    @user.resumes.create!(complete_name: "Saved CV", is_draft: false,
                   email: "confirm-saved-#{SecureRandom.hex(4)}@example.com")
    @user.resumes.create!(complete_name: "Draft CV", is_draft: true,
                   email: "confirm-draft-#{SecureRandom.hex(4)}@example.com")
  end

  test "every delete form is intercepted by the confirm dialog and none rely on turbo confirm" do
    get profile_url
    assert_response :success

    assert_select "[data-controller~='confirm-delete']", 1
    assert_select "[data-turbo-confirm]", 0

    # Sign-out in the shared header is also a DELETE form; only data deletions need confirming.
    delete_forms = css_select("form").select do |f|
      f.at_css("input[name='_method'][value='delete']") && !f["action"].to_s.include?("logout")
    end
    assert_operator delete_forms.size, :>=, 3
    delete_forms.each do |form|
      assert_equal "submit->confirm-delete#intercept", form["data-action"]
      assert form["data-confirm-delete-title-param"].present?
      assert form["data-confirm-delete-body-param"].present?
    end

    assert_select "dialog[data-confirm-delete-target='dialog']", 1
    assert_select "dialog [data-confirm-delete-target='confirmButton'].bg-red-600", 1
    assert_select "dialog button[data-confirm-delete-cancel]", 1
  end

  test "account deletion requires typing the confirmation phrase" do
    get profile_url
    account_form = css_select("form[action='#{profile_path}']").find do |f|
      f.at_css("input[name='_method'][value='delete']")
    end
    assert account_form, "account delete form missing"
    assert_equal I18n.t("ux_confirm.account_phrase", locale: :ar),
                 account_form["data-confirm-delete-phrase-param"]
  end

  test "icon-only resume buttons have accessible names" do
    get profile_url
    name = "Saved CV"
    %w[view_resume edit_resume download_pdf].each do |key|
      assert_select "a[aria-label=?]", I18n.t("ux_confirm.aria.#{key}", name: name, locale: :ar)
    end
    assert_select "button[aria-label=?]", I18n.t("ux_confirm.aria.delete_resume", name: name, locale: :ar)
    assert_select "button[aria-label=?]", I18n.t("ux_confirm.aria.delete_draft", name: "Draft CV", locale: :ar)
  end

  test "ux_confirm locale keys exist in both languages" do
    %i[en ar].each do |locale|
      %w[cancel delete type_to_confirm resume_title resume_body draft_title draft_body
         account_title account_body account_confirm account_phrase].each do |key|
        assert I18n.exists?("ux_confirm.#{key}", locale), "missing #{locale}.ux_confirm.#{key}"
      end
    end
  end
end
