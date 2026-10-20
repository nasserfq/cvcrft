require "test_helper"

class AiProgressPartialTest < ActionView::TestCase
  def render_card(**locals)
    render partial: "shared/ai_progress",
           locals: { id: "p", dir: "ltr", title: "Working", error_title: "Failed", error_text: "Oops",
                     retry_label: "Try again", retry_href: "/again" }.merge(locals)
    Nokogiri::HTML5.fragment(rendered)
  end

  test "carries a hidden check-again button and timeout copy for the polling limit" do
    doc = render_card
    recheck = doc.at_css("[data-ai-progress-recheck]")

    assert recheck
    assert recheck.key?("hidden")
    assert_equal "Failed", doc.at_css("[data-ai-progress-error-title]")["data-default"]
    assert doc.at_css("[data-ai-progress-error-title]")["data-timeout"].present?
    assert doc.at_css("[data-ai-progress-error]")["data-timeout"].present?
    assert_equal "/again", doc.at_css("[data-ai-progress-fail] a")["href"]
  end

  test "uses the Arabic timeout copy under the Arabic locale and accepts overrides" do
    I18n.with_locale(:ar) do
      doc = render_card
      assert_match(/[؀-ۿ]/, doc.at_css("[data-ai-progress-recheck]").text)
    end

    doc = render_card(timeout_text: "Custom", recheck_label: "Poll again")
    assert_equal "Custom", doc.at_css("[data-ai-progress-error]")["data-timeout"]
    assert_includes doc.at_css("[data-ai-progress-recheck]").text, "Poll again"
  end

  test "poll gives up after a time limit or repeated network errors" do
    script = render_card.at_css("script").text

    assert_includes script, "maxSeconds || 180"
    assert_includes script, "maxNetworkErrors || 6"
    assert_includes script, "giveUp()"
  end
end
