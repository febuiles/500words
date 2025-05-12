class PagesController < ApplicationController
  def home
    @post = Post.new if logged_in?
  end

  def about
  end
end
