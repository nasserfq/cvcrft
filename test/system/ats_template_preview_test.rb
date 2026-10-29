require "application_system_test_case"

class AtsTemplatePreviewTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  PICKER = "[data-testid=ats-template-picker]".freeze

  setup do
    @user = users(:one)
    create_test_resume(@user)
    sign_in @user
    @keys = AtsTemplatePdfService.template_catalog.map { |item| item[:key].to_s }
  end

  %w[en ar].each do |locale|
    test "template thumbnails, preview dialog and selection work in #{locale}" do
      visit new_cv_generation_path(locale: locale)

      assert_selector "html[dir=#{locale == 'ar' ? 'rtl' : 'ltr'}]", visible: :all
      # The picker renders after Babel compiles the page and the resume list loads.
      assert_selector "#{PICKER} img", count: @keys.size, visible: :all, wait: 20
      decline_analytics_banner(locale)

      # Opening a preview shows the dialog; Escape closes it.
      first("#{PICKER} [data-testid=ats-preview-button]").click
      assert_selector "[role=dialog][aria-modal=true]"
      # Focus moves into the dialog (its Close button), so Escape goes to the page from there.
      page.send_keys(:escape)
      assert_no_selector "[role=dialog]"

      # A backdrop click closes it too.
      first("#{PICKER} [data-testid=ats-preview-button]").click
      find("[data-testid=ats-preview-backdrop]").click(x: 5, y: 5, offset: :top_left)
      assert_no_selector "[role=dialog]"

      # "Use this template" selects the previewed card and closes the dialog.
      target = @keys.last
      within("#{PICKER} [data-template-key='#{target}']") do
        assert_selector "button[aria-pressed=false]"
        find("[data-testid=ats-preview-button]").click
      end
      within("[role=dialog]") do
        # The full-size image grows the dialog when it loads and moves the buttons.
        wait_for_preview_image
        click_on I18n.t("cv_generation.use_template", locale: locale)
      end
      assert_no_selector "[role=dialog]"
      assert_selector "#{PICKER} [data-template-key='#{target}'] button[aria-pressed=true]"
    end
  end

  private

  def wait_for_preview_image
    page.document.synchronize do
      loaded = page.evaluate_script("(() => { const img = document.querySelector('[role=dialog] img'); return !img || img.complete; })()")
      raise Capybara::ExpectationNotMet, "preview image still loading" unless loaded
    end
  end

  # The consent banner is fixed to the bottom of the viewport and can cover lower cards.
  def decline_analytics_banner(locale)
    decline = I18n.t("consent.decline", locale: locale)
    click_on(decline) if has_button?(decline, wait: 1)
  end
end
