Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    get "components", to: "components#index", as: :components

    resources :dashboard, only: [:index]
    resources :finance, only: [:index]
    get "data", to: "data#index", as: :data
    get "data/financial_report", to: "data#financial_report", as: :data_financial_report
    get "data/customer_info", to: "data#customer_info", as: :data_customer_info
    get "data/attendee_list", to: "data#attendee_list", as: :data_attendee_list
    get "data/upload", to: "data#upload", as: :data_upload
    post "data/upload", to: "data#upload_customers", as: :data_upload_customers
    resources :exports, only: [:index, :new, :create, :show]
    resources :settings, only: [:index, :new, :create, :edit, :update, :destroy] do
      get "promotion_drilldown/:id", action: :promotion_drilldown, as: :promotion_drilldown, on: :collection
      get "promotion_export", action: :promotion_export, on: :collection
    end
    resources :customers, only: [:index, :show, :edit, :update] do
      collection do
        post :sync_duplicates
      end
      member do
        post :sync_document_info
        get :export_customer_info
        get :export_billing_accounting
        get :export_customer_template
      end
    end
    resources :training_classes do
      get :finance, on: :member, action: :finance, as: :finance
      resources :attendees do
        collection do
          get :export
        end
        member do
          get :move_to_potential
          patch :move_to_potential
          get :move_to_attendee
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
  
  # CFO Finance Dashboard (Turbo-driven filters)
  get "finance_dashboard", to: "finance_dashboards#index", as: :finance_dashboard

  # Root redirects to admin dashboard
  root "admin/dashboard#index"
end
