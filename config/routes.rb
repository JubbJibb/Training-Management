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

  # ========== Financials module: /financials/* ==========
  scope "financials", module: "financials", as: "financials" do
    get "overview", to: "overview#index", as: :overview
    get "overview/kpi_detail", to: "overview#kpi_detail", as: :overview_kpi_detail
    get "accounts_receivable", to: "accounts_receivable#index", as: :accounts_receivable
    resources :payments, only: [:index, :show], controller: "payments" do
      member do
        get :summary
        get :download_pdf
        post :send_summary
        get :panel
        patch :verify_slip
        patch :reject_slip
        patch :issue_receipt
      end
      collection do
        post :bulk_verify
        post :bulk_send_summary
        post :bulk_send_receipt
        get :bulk_export
      end
    end
    get "expenses", to: "expenses#index", as: :expenses
    get "compliance", to: "compliance#index", as: :compliance
    get "export_history", to: "export_history#index", as: :export_history
  end

  # Backward compatibility: /finance -> financials overview
  get "finance", to: redirect("/financials/overview"), as: :financial_overview
  get "finance/ar", to: redirect("/financials/accounts_receivable"), as: :finance_ar
  get "finance/payments", to: redirect("/financials/payments"), as: :finance_payments
  get "finance/expenses", to: redirect("/financials/expenses"), as: :finance_expenses
  get "finance/compliance", to: redirect("/financials/compliance"), as: :finance_compliance
  get "finance/export_jobs", to: redirect("/financials/export_history"), as: :finance_export_jobs
  get "finance_dashboard", to: redirect("/financials/overview"), as: :finance_dashboard

  # ========== Executive IA: Operations / Clients / Strategy (pretty URLs) ==========
  get "training_classes", to: redirect("/admin/training_classes")
  scope "operations", module: "operations", as: "operations" do
    get "calendar", to: redirect("/operations/training_calendar"), as: :calendar
    get "calendar/event/:id", to: "calendar#event", as: :calendar_event
    # Ops-focused training calendar: drawer, quick add, filters
    get "training_calendar", to: "training_calendar#index", as: :training_calendar
    get "training_calendar/drawer", to: "training_calendar#drawer", as: :training_calendar_drawer
    get "training_calendar/drawer/:id", to: "training_calendar#drawer", as: :training_calendar_drawer_class, constraints: { id: /\d+/ }
    get "training_calendar/day_popover", to: "training_calendar#day_popover", as: :training_calendar_day_popover
    get "training_calendar/quick_add_form", to: "training_calendar#quick_add_form", as: :training_calendar_quick_add_form
    post "training_calendar/classes", to: "training_calendar#create_class", as: :training_calendar_create_class
    patch "training_calendar/classes/:id", to: "training_calendar#update_class", as: :training_calendar_update_class
    get "training_classes", to: redirect("/admin/training_classes"), as: :training_classes
    get "courses", to: redirect("/admin/courses"), as: :courses
    get "instructors", to: redirect("/instructors"), as: :instructors
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

  # ========== Public class landing page ==========
  get "classes/:public_slug", to: "public/classes#show", as: :public_class, constraints: { public_slug: /[a-z0-9\-]+/ }

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
    # Classes: list + single entry for "view class" (workspace). Edit/delete stay under training_classes.
    get "classes", to: "training_classes#index", as: :classes
    get "classes/:id", to: "class_workspace#show", as: :class_workspace
    get "classes/:id/overview", to: "class_workspace#overview", as: :class_workspace_overview
    get "classes/:id/attendees", to: "class_workspace#attendees", as: :class_workspace_attendees
    get "classes/:id/leads", to: "class_workspace#leads", as: :class_workspace_leads
    get "classes/:id/documents", to: "class_workspace#documents", as: :class_workspace_documents
    get "classes/:id/finance", to: "class_workspace#finance", as: :class_workspace_finance
    get "classes/:id/edit", to: "class_workspace#edit", as: :class_workspace_edit
    patch "classes/:id/checklist", to: "class_workspace#update_checklist", as: :class_workspace_checklist
    patch "classes/:id/public", to: "class_workspace#update_public", as: :class_workspace_public
    patch "classes/:id/notes", to: "class_workspace#update_notes", as: :class_workspace_notes

    resources :training_classes do
      get :finance, on: :member, action: :finance, as: :finance
      get :copy, on: :member, action: :copy, as: :copy
      member do
        patch :toggle_public
        patch :update_related_links
        patch :update_checklist
        post :add_note
        delete :delete_note
      end
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
