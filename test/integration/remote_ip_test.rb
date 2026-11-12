require "test_helper"

class RemoteIpTest < ActionDispatch::IntegrationTest
  test "a Client-IP header that disagrees with X-Forwarded-For does not 500" do
    get "/", headers: {
      "Client-IP" => "57.150.36.214",
      "X-Forwarded-For" => "141.101.76.8, 172.18.0.5"
    }
    assert_response :success
    assert_equal "141.101.76.8", request.remote_ip
  end
end
