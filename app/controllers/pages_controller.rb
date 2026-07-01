class PagesController < ApplicationController
  def home
    @post = Post.new if logged_in?
  end

  def styleguide
  end
end
