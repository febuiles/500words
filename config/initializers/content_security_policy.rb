# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # Google Fonts serves the font files (woff2) from fonts.gstatic.com.
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self
    # Allow the Google Fonts stylesheet. Host sources are honored alongside the
    # per-request nonce below (nonces only gate inline styles, not linked ones).
    policy.style_src   :self, "https://fonts.googleapis.com"
    policy.base_uri    :self
    policy.form_action :self
    # This app is not meant to be embedded in a frame.
    policy.frame_ancestors :none
  end

  # Generate session nonces for permitted importmap and inline scripts/styles.
  # importmap-rails and Turbo read the nonce (via csp_meta_tag in the layout) so
  # their injected <script type="importmap"> and progress-bar styles are allowed.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
