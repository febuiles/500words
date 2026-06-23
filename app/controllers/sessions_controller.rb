class SessionsController < ApplicationController
  def new
  end

  def create
    if (user = User.authenticate_by(email: params[:email].to_s.strip.downcase, password: params[:password]))
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Logged out."
  end
end
