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
    resources :settings, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :customers, only: [:index, :show, :edit, :update]
    resources :training_classes do
      resources :attendees, except: [:show] do
        collection do
          get :export
        end
        member do
          patch :move_to_potential
          patch :move_to_attendee
          post :send_email
        end
      end
      resources :class_expenses, except: [:show, :index]
      member do
        post :send_email_to_all
      end
    end
  end
  
  # Root redirects to admin dashboard
  root "admin/dashboard#index"
end
