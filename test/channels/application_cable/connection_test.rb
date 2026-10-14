require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects as the signed-in user" do
    connect env: { "warden" => stub(user: users(:one)) }

    assert_equal users(:one), connection.current_user
  end

  test "rejects a signed-out visitor" do
    assert_reject_connection { connect env: { "warden" => stub(user: nil) } }
  end
end
