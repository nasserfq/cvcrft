require "test_helper"

class Coach::Tools::SaveSectionTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @chat = Coach::Chat.create!(user: users(:one), path: "scratch", draft: { "complete_name" => "Sara" })
    @tool = Coach::Tools::SaveSection.new(@chat)
  end

  test "is called save_section" do
    assert_equal "save_section", @tool.name
  end

  test "a valid section is saved and broadcast" do
    json = [ { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01", "end_date" => "2022-01" } ].to_json

    assert_equal "saved", @tool.call(section: "work_experience", json: json)

    draft = @chat.reload.draft
    assert_equal "Panda", draft["work_experience"].first["company"]
    assert_broadcast_on("coach:#{@chat.id}", type: "draft", draft: draft)
  end

  test "bad JSON returns an error and leaves the draft alone" do
    result = @tool.call(section: "work_experience", json: "[{oops")

    assert result[:error].present?
    assert_equal({ "complete_name" => "Sara" }, @chat.reload.draft)
  end

  test "a bad section returns an error and leaves the draft alone" do
    result = @tool.call(section: "hobbies", json: "[]")

    assert_includes result[:error], "unknown section"
    assert_equal({ "complete_name" => "Sara" }, @chat.reload.draft)
    assert_no_broadcasts("coach:#{@chat.id}")
  end
end
