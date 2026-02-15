Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # ========== Executive IA: Insights (real dashboard pages) ==========
  get "insights", to: redirect("/insights/business"), as: :insights
  scope "insights", module: "insights", as: "insights" do
    get "business", to: "business#index", as: :business
    get "financial", to: "financial#index", as: :financial
    get "strategy", to: "strategy#index", as: :strategy
    get "actions", to: "actions#index", as: :actions
  end

  # ========== Executive IA: Financials ==========
  get "finance", to: "finance_dashboards#index", as: :financial_overview
  get "finance/ar", to: "admin/finance#index", as: :finance_ar
  get "finance/payments", to: "admin/finance#index", as: :finance_payments

  scope "financials", module: "financials", as: "financials" do
    get "payment_tracking", to: "payment_tracking#index", as: :payment_tracking
    resources :payments, only: [:show], controller: "payments" do
      member do
        get :download_pdf
        post :send_summary
      end
    end
  end
  get "finance/expenses", to: "admin/expenses#index", as: :finance_expenses
  get "finance/compliance", to: "admin/compliance#index", as: :finance_compliance
  get "finance/export_jobs", to: "admin/exports#index", as: :finance_export_jobs
  # Backward compatibility: old CFO dashboard URL
  get "finance_dashboard", to: redirect("/finance"), as: :finance_dashboard

  # ========== Executive IA: Operations / Clients / Strategy (pretty URLs) ==========
  get "training_classes", to: redirect("/admin/training_classes")
  scope "operations", module: "operations", as: "operations" do
    get "calendar", to: "calendar#index", as: :calendar
    get "calendar/event/:id", to: "calendar#event", as: :calendar_event
  end
  get "courses", to: redirect("/admin/courses")
  get "instructors", to: "admin/instructors#index", as: :instructors
  get "customers", to: redirect("/admin/customers")
  get "companies", to: redirect("/admin/customers?segment=Corp")
  get "promotions", to: redirect("/admin/settings")
  get "promotions/performance", to: redirect("/admin/settings#performance")

  # ========== Clients: Corporate Accounts + Client Analysis ==========
  scope "clients", module: "clients", as: "clients" do
    get "corporate_accounts", to: "corporate_accounts#index", as: :corporate_accounts
    get "corporate_accounts/:id", to: "corporate_accounts#show", as: :corporate_account
    get "analysis", to: "analysis#show", as: :analysis
  end

  # ========== Admin namespace ==========
  namespace :admin do
    root "dashboard#index"
    get "components", to: "components#index", as: :components

    resources :dashboard, only: [:index]
    resources :finance, only: [:index]
    resources :instructors, only: [:index]
    resources :expenses, only: [:index]
    resources :compliance, only: [:index]
    get "data", to: "data#index", as: :data
    get "data/financial_report", to: "data#financial_report", as: :data_financial_report
    get "data/customer_info", to: "data#customer_info", as: :data_customer_info
    get "data/attendee_list", to: "data#attendee_list", as: :data_attendee_list
    get "data/upload", to: "data#upload", as: :data_upload
    post "data/upload", to: "data#upload_customers", as: :data_upload_customers
    resources :courses, only: [:index, :show, :edit, :update] do
      collection do
        post :sync
      end
    end
    resources :exports, only: [:index, :new, :create, :show]
    resources :settings, only: [:index, :new, :create, :edit, :update, :destroy] do
      get "promotion_drilldown/:id", action: :promotion_drilldown, as: :promotion_drilldown, on: :collection
      get "promotion_export", action: :promotion_export, on: :collection
    end
    resources :customers, only: [:index, :show, :new, :create, :edit, :update] do
      collection do
        post :sync_duplicates
        post :merge
      end
      member do
        match :sync_document_info, via: [:get, :post]
        get :export_customer_info
        get :export_billing_accounting
        get :export_customer_template
        get :edit_billing_tax
        patch :update_billing_tax
        get :register_for_class
      end
    end
    resources :training_classes do
      get :finance, on: :member, action: :finance, as: :finance
      resources :attendees do
        collection do
          get :export
          get :export_documents
        end
        member do
          get :move_to_potential
          patch :move_to_potential
          get :move_to_attendee
          patch :move_to_attendee
          post :send_email
          post :sync_tax_from_customer
        end
      end
      resources :class_expenses, except: [:show, :index]
      member do
        post :send_email_to_all
      end
    end
  end

  # Root / landing page: Training Classes
  root to: redirect("/admin/training_classes")
end
