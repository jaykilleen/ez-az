Rails.application.routes.draw do
  get "/tv", to: "tv#show"

  get "/counter", to: "counters#show"

  namespace :api do
    resources :scores, only: [:index, :create]
  end

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_error", via: :all
end
