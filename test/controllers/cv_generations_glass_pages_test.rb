require "test_helper"

# The CV generation pages and the credits page use the Seera glass design
# inside the app layout (shared header, ambient, footer), dark only, and the
# generation and import controllers speak through ux_i18n2 keys.
class CvGenerationsGlassPagesTest < ActionDispatch::IntegrationTest
  LIGHT_ONLY = /\b(?:dark:[\w\/\[\]-]+|bg-gray-50|bg-white(?!\/| keep-light)|text-gray-900|bg-emerald-50)\b/

  setup do
    @user = users(:one)
    sign_in @user
    @resume = @user.resumes.create!(complete_name: "Glass User", is_draft: false,
                             email: "glass-#{SecureRandom.hex(4)}@example.com")
    @generation = CvGeneration.create!(user: @user, resume: @resume, ai_model: "gpt-4", status: "completed",
                                       job_description: "Senior Rails engineer",
                                       generated_content: "A tailored summary.")
  end

  teardown { ENV.delete("BILLING_ENABLED") }

  test "new renders inside the app layout with a full reload on Turbo visits" do
    get new_cv_generation_url(locale: "en")

    assert_response :success
    assert_equal 1, response.body.scan(/<html/i).size
    assert_select "header", minimum: 1
    assert_select "main#main .sr-page #cv-generation-results"
    assert_select "meta[name=turbo-visit-control][content=reload]"
    assert_select "body.sr-app-long"
    assert_no_match LIGHT_ONLY, main_html
    assert_no_match(/unpkg\.com\/lucide/, response.body)
  end

  test "index lists generations as glass cards" do
    get cv_generations_url(locale: "en")

    assert_response :success
    assert_select "main#main .sr-page"
    assert_select "article#cv_generation_#{@generation.id}.glass"
    assert_select "[data-status=completed]", text: /Completed/
    assert_select "h1", text: /Generated CVs/
    assert_no_match LIGHT_ONLY, main_html
  end

  test "index shows the glass empty state in Arabic" do
    CvGeneration.where(user: @user).delete_all

    get cv_generations_url(locale: "ar")

    assert_response :success
    assert_select "section.glass h2", text: I18n.t("ux_i18n2.cv_generations.index.empty_title", locale: :ar)
  end

  test "show is server rendered glass without the in-browser React copy" do
    get cv_generation_url(@generation, locale: "en")

    assert_response :success
    assert_select "aside.glass dl"
    assert_select "section.glass", text: /A tailored summary\./
    assert_no_match(/text\/babel|unpkg\.com\/react/, response.body)
    assert_no_match LIGHT_ONLY, main_html
  end

  test "show polls while a generation is processing" do
    @generation.update!(status: "processing")

    get cv_generation_url(@generation, locale: "en")

    assert_select "#cvgen-show-processing[role=status]"
    assert_includes response.body, cv_generation_path(@generation, format: :json)
  end

  test "credits page is glass and dark only" do
    ENV["BILLING_ENABLED"] = "true"
    get credits_url(locale: "en")

    assert_response :success
    assert_select ".sr-page section.glass"
    assert_no_match LIGHT_ONLY, main_html
  end

  test "generation limit message comes from ux_i18n2 in the request locale" do
    UserUsageLimits.any_instance.stubs(:can_generate_job_based?).returns(false)
    UserUsageLimits.any_instance.stubs(:max_job_based_generations).returns(5)

    post cv_generations_url(format: :json, locale: "ar"), params: {
      cv_generation: { job_description: "Rails", resume_id: @resume.id }
    }

    assert_response :too_many_requests
    assert_equal "لقد استخدمت جميع رصيد إنشاء السيرة الذاتية من وصف الوظيفة (5).", response.parsed_body["error"]
  end

  test "cv import messages are translated" do
    post cv_import_path(locale: "en")
    assert_equal "Please upload your CV as a PDF file", response.parsed_body["error"]

    post cv_import_path(locale: "ar")
    assert_equal "يرجى تحميل ملف السيرة الذاتية (PDF)", response.parsed_body["error"]
  end

  test "ux_i18n2 has the same keys in English and Arabic" do
    flat = lambda do |hash, prefix = nil|
      hash.flat_map { |k, v| v.is_a?(Hash) ? flat.call(v, [ prefix, k ].compact.join(".")) : [ [ prefix, k ].compact.join(".") ] }
    end
    en = flat.call(I18n.t("ux_i18n2", locale: :en))
    ar = flat.call(I18n.t("ux_i18n2", locale: :ar))

    assert_equal en.sort, ar.sort
    assert_equal "يجب عليك إنشاء سيرة ذاتية أولاً قبل إنشاء سير ذاتية مخصصة بناءً على وصف الوظيفة.",
                 I18n.t("ux_i18n2.cv_generations.need_resume_first", locale: :ar)
  end

  private

  def main_html
    response.body[%r{<main id="main".*</main>}m].to_s.presence || flunk("no main element")
  end
end
