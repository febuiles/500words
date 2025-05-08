class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]
  
  def new
    @post = current_user.posts.build
  end

  def create
    @post = current_user.posts.build(post_params)
    
    if @post.save
      redirect_to @post, notice: "Post created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def index
    @posts = Post.order(created_at: :desc)
  end

  def show
  end
  
  def destroy
    @post.destroy
    redirect_to posts_path, notice: "Post deleted successfully!"
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def authorize_user!
    redirect_to posts_path, alert: "You are not authorized to perform this action" unless @post.user == current_user
  end
  
  def post_params
    params.require(:post).permit(:content)
  end
end
