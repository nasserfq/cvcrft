require "test_helper"

class RemoteIpTest < ActionDispatch::IntegrationTest
  # What production sends: kamal-proxy puts the Cloudflare edge in
  # X-Forwarded-For, Thruster adds kamal-proxy's container address.
  EDGE = "141.101.76.8, 172.18.0.5".freeze

  test "a Client-IP header that disagrees with X-Forwarded-For does not 500" do
    get "/", headers: { "Client-IP" => "57.150.36.214", "X-Forwarded-For" => EDGE }
    assert_response :success
  end

  test "behind Cloudflare the visitor's IP comes from CF-Connecting-IP" do
    get "/", headers: { "X-Forwarded-For" => EDGE, "CF-Connecting-IP" => "203.0.113.7" }
    assert_equal "203.0.113.7", request.remote_ip
  end

  test "CF-Connecting-IP is ignored when the request did not come through Cloudflare" do
    get "/", headers: { "X-Forwarded-For" => "198.51.100.9, 172.18.0.5", "CF-Connecting-IP" => "203.0.113.7" }
    assert_equal "198.51.100.9", request.remote_ip
  end

  test "a malformed CF-Connecting-IP falls back to the edge address" do
    get "/", headers: { "X-Forwarded-For" => EDGE, "CF-Connecting-IP" => "not-an-ip" }
    assert_equal "141.101.76.8", request.remote_ip
  end
end
