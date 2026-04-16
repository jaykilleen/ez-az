Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "/tv", to: "tv#show"

  resources :rooms, only: [:new, :create, :show], param: :code do
    member do
      get  :join,     action: :join
      post :join,     action: :add_member
      get  :play
      post :start
    end
  end

  get "/room-input.js",    to: "room_input#show", defaults: { format: :js }
  get "/manifest.json",    to: "manifest#show"
  get "/icons/:name.:format", to: "icons#show", constraints: { format: /png|jpg|jpeg|svg|webp/ }

  get "/counter", to: "counters#show"

  namespace :api do
    resources :scores,  only: [:index, :create]
    resource  :session, only: [:show, :create, :destroy]
    get "version", to: "version#show"
    resources :players, only: [:create] do
      collection { get :check }
    end
    resources :errors,  only: [:create]
  end

  get "/errors", to: "errors_dashboard#index"

  match "/404", to: "errors#not_found",       via: :all
  match "/500", to: "errors#internal_error",  via: :all
end
