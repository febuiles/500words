class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path, alert: "Too many attempts. Please try again later." }

  def new
  end

  def create
    if (user = User.authenticate_by(email: params[:email].to_s.strip.downcase, password: params[:password]))
      reset_session
      start_new_session_for user
      redirect_to root_path, notice: "Logged in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    reset_session
    redirect_to root_path, notice: "Logged out."
  end
end
