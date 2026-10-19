require "test_helper"

class LegacyHostRedirectTest < ActiveSupport::TestCase
  setup do
    app = ->(_env) { [ 200, {}, [ "ok" ] ] }
    @middleware = LegacyHostRedirect.new(app, legacy_hosts: [ "500words.co" ], canonical_host: "500words.xyz")
  end

  test "redirects the legacy domain to the canonical host, keeping path and query" do
    status, headers, _ = @middleware.call(Rack::MockRequest.env_for("https://500words.co/posts/1?page=2"))

    assert_equal 301, status
    assert_equal "https://500words.xyz/posts/1?page=2", headers["location"]
  end

  test "redirects subdomains of the legacy domain" do
    status, headers, _ = @middleware.call(Rack::MockRequest.env_for("https://www.500words.co/"))

    assert_equal 301, status
    assert_equal "https://500words.xyz/", headers["location"]
  end

  test "passes through requests for other hosts" do
    status, _, _ = @middleware.call(Rack::MockRequest.env_for("https://500words.xyz/"))
    assert_equal 200, status

    status, _, _ = @middleware.call(Rack::MockRequest.env_for("https://not500words.co/"))
    assert_equal 200, status
  end
end
