class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :edit, :update, :destroy]

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
    @posts = current_user.posts.order(created_at: :desc)
  end

  def show
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "Post deleted successfully!"
  end

  private

  # Posts are always looked up through the current user's association, so a
  # request for someone else's (or a nonexistent) post resolves to the same
  # 404 — a single authorization boundary that never reveals whether the
  # record exists.
  def set_post
    @post = current_user.posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def post_params
    params.require(:post).permit(:content)
  end
end
