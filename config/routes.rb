Rails.application.routes.draw do
  root "pages#index"
  get 'pages/index'
  get 'sign-in-development/:id', to: 'pages#sign_in_development', as: :sign_in_development

  resources :articles

  get "show_jwt", controller: "application_user"

  devise_for :users

  namespace :api do
    namespace :v1 do
      defaults format: :json do
        resources :articles
      end
    end
  end
end
