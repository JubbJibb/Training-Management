Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    
    resources :dashboard, only: [:index]
    resources :finance, only: [:index]
    resources :training_classes do
      resources :attendees, except: [:show] do
        collection do
          get :export
        end
      end
    end
  end
  
  # Root redirects to admin dashboard
  root "admin/dashboard#index"
end
