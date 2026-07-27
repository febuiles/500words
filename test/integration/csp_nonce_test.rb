require "test_helper"

# Regression coverage for the CSP nonce.
#
# The nonce generator used to be `request.session.id.to_s`, which is nil (so "")
# until something is written to the session. Logged-out visitors therefore got
# `script-src 'self' 'nonce-'` plus `nonce=""` on the inline importmap, which the
# browser refused to run — silently killing every Stimulus controller, including
# the word counter on the home page.
class CspNonceTest < ActionDispatch::IntegrationTest
  test "logged-out visitor gets a non-empty nonce on the inline importmap" do
    get root_path
    assert_response :success

    nonce = csp_nonce_from_header
    assert nonce.present?, "CSP header advertised an empty nonce: #{csp_header}"

    assert_match %r{<script type="importmap"[^>]*nonce="#{Regexp.escape(nonce)}"}, response.body,
      "inline importmap nonce does not match the one in the Content-Security-Policy header"
    assert_match %r{<script type="module" nonce="#{Regexp.escape(nonce)}">}, response.body,
      "inline module script nonce does not match the one in the Content-Security-Policy header"
  end

  test "nonce in the csp-nonce meta tag matches the response header" do
    get root_path

    nonce = csp_nonce_from_header
    assert nonce.present?
    # Turbo reads the nonce from this meta tag to nonce its own injected styles.
    assert_match %r{<meta name="csp-nonce" content="#{Regexp.escape(nonce)}"}, response.body
  end

  test "nonce is fresh per request" do
    get root_path
    first = csp_nonce_from_header

    get root_path
    assert_not_equal first, csp_nonce_from_header
  end

  private
    def csp_header
      response.headers["Content-Security-Policy"]
    end

    def csp_nonce_from_header
      csp_header[/'nonce-([^']*)'/, 1]
    end
end
