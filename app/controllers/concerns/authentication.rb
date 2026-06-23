module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_session
    helper_method :current_user, :logged_in?
  end

  private

  def set_current_session
    Current.session = find_session
  end

  def find_session
    return unless (session_id = cookies.signed[:session_id])

    Session.find_by(id: session_id)
  end

  def current_user
    Current.user
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to login_path, alert: "You must be logged in to access this page" unless logged_in?
  end

  def start_new_session_for(user)
    session_record = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    Current.session = session_record
    cookies.signed.permanent[:session_id] = {
      value: session_record.id,
      httponly: true,
      same_site: :lax,
      # Explicit in addition to force_ssl upgrading cookies in production. Lax
      # (not Strict) so the user isn't treated as logged out when arriving via
      # an external link.
      secure: Rails.env.production?
    }
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end
end
