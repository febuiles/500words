Rails.application.routes.draw do
  # User authentication routes
  get "signup", to: "users#new", as: :signup
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Static pages
  get "styleguide", to: "pages#styleguide", as: :styleguide

  # Resources
  resources :users, only: [:create, :show, :destroy]
  resources :posts

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path
  root "pages#home"
end
