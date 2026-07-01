class UsersController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to signup_path, alert: "Too many attempts. Please try again later." }

  before_action :authenticate_user!, only: [:show, :destroy]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password_confirmation = user_params[:password]

    if @user.save
      reset_session
      start_new_session_for @user
      redirect_to root_path, notice: "Account created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
    return redirect_to posts_path, alert: "You are not authorized to view this profile" unless @user == current_user
  end

  # Deletes the signed-in account and, via `dependent: :destroy`, all of its
  # posts and sessions. A user can only ever delete themselves.
  def destroy
    user = current_user
    terminate_session
    reset_session
    user.destroy
    redirect_to root_path, notice: "Your account and all its posts were deleted.", status: :see_other
  end

  private

  def user_params
    params.require(:user).permit(:email, :username, :password)
  end
end
