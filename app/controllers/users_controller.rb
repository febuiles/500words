class UsersController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to signup_path, alert: "Too many attempts. Please try again later." }

  before_action :authenticate_user!, only: [:show]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password_confirmation = user_params[:password]

    if @user.save
      reset_session
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Account created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
    return redirect_to posts_path, alert: "You are not authorized to view this profile" unless @user == current_user
    @posts = @user.posts.order(created_at: :desc)
  end

  private

  def user_params
    params.require(:user).permit(:email, :username, :password)
  end
end
