Rails.application.routes.draw do
  resources :articles
  get 'pages/index'
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "pages#index"
end
