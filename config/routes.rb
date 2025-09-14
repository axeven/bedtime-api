Rails.application.routes.draw do
  # Mount rswag routes only if gems are available (development environment)
  if defined?(Rswag::Ui) && defined?(Rswag::Api)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :users, only: [:create]
      resources :sleep_records, only: [:create, :show, :update, :index, :destroy] do
        collection do
          get :current
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
