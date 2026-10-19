require "test_helper"

class IconHelperTest < ActionView::TestCase
  test "renders a vendored icon as inline svg" do
    html = seera_icon("solar:info-circle-bold", width: 20, class: "text-primary mt-0.5")
    svg = Nokogiri::HTML5.fragment(html).at_css("svg")

    assert_predicate html, :html_safe?
    assert_equal "20", svg["width"]
    assert_equal "20", svg["height"]
    assert_equal "0 0 24 24", svg["viewbox"] || svg["viewBox"]
    assert_equal "true", svg["aria-hidden"]
    assert_equal "inline-block align-middle text-primary mt-0.5", svg["class"]
    assert_includes html, "currentColor"
    assert svg.at_css("path")
  end

  test "defaults to 24px and passes extra attributes through" do
    svg = Nokogiri::HTML5.fragment(seera_icon("solar:pen-bold", data: { role: "edit" })).at_css("svg")

    assert_equal "24", svg["width"]
    assert_equal "edit", svg["data-role"]
    assert_equal "inline-block align-middle", svg["class"]
  end

  test "every icon used on the legal pages is vendored" do
    names = Dir[Rails.root.join("app/views/pages/**/*.erb")].flat_map do |path|
      File.read(path).scan(/seera_icon\("([^"]+)"/).flatten
    end.uniq

    assert_not_empty names
    assert_empty names - IconHelper::ICONS.keys
  end

  test "unknown icon raises outside production" do
    assert_raises(IconHelper::UnknownIconError) { seera_icon("solar:nope") }
  end

  test "unknown icon renders nothing in production" do
    Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new("production"))

    assert_equal "", seera_icon("solar:nope")
  end
end
