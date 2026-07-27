require "test_helper"

# The icons are served through the asset pipeline rather than as static
# /icon.{svg,png} files. Static public/ files go out with a one-year
# cache-control, so a redesigned icon never reached anyone who had already
# visited the site. Digested URLs change whenever the file does.
class FaviconTest < ActionDispatch::IntegrationTest
  test "icon links point at digest-stamped asset URLs" do
    get root_path
    assert_response :success

    assert_match %r{<link rel="icon" href="/assets/icon-\w+\.svg" type="image/svg\+xml">}, response.body
    assert_match %r{<link rel="icon" href="/assets/icon-\w+\.png" type="image/png">}, response.body
    assert_match %r{<link rel="apple-touch-icon" href="/assets/icon-\w+\.png">}, response.body
  end

  test "icons resolve through the asset pipeline" do
    assert Rails.application.assets.load_path.find("icon.svg"), "icon.svg missing from the asset load path"
    assert Rails.application.assets.load_path.find("icon.png"), "icon.png missing from the asset load path"
  end
end
