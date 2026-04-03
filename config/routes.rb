Rails.application.routes.draw do
  # Health check route for Kamal
  get "/up", to: "application#health_check"

  # PostHog reverse proxy routes to avoid ad blockers
  match "/ingest/*path", to: "posthog_proxy#ingest", via: :all
  match "/ingest", to: "posthog_proxy#ingest", via: :all
  match "/ph-static/*path", to: "posthog_proxy#static", via: :all
  match "/decide/*path", to: "posthog_proxy#decide", via: :all
  match "/decide", to: "posthog_proxy#decide", via: :all

  # Locale switching route
  patch "/locale/:locale", to: "locales#update", as: :locale

  # Devise routes (for authentication helpers)
  devise_for :users, skip: [ :registrations, :sessions, :passwords, :confirmations, :unlocks ]

  # Root route
  root "home#index"

  # Static pages
  get "/privacy", to: "pages#privacy", as: :privacy

  # User profile route
  resource :profile, only: [ :show, :destroy ]

  # Test Sidekiq route
  get "/test_sidekiq", to: "home#test_sidekiq"

  # Resume routes with nested resources
  resources :resumes do
    resources :work_experiences, only: [ :create, :update, :destroy ]
    resources :skills, only: [ :create, :update, :destroy ]

    # Custom actions
    member do
      get :generate_pdf
      post :optimize_ats
      post :save_draft
      post :resume_draft
      # Progressive loading endpoints
      get :experiences
      get :skills_section
      get :educations
      get :certifications_section
      get :languages_section
    end

    # Test endpoint
    get :test_auth, on: :collection
  end

  # AI Translation routes
  resources :ai_translations, only: [ :create ] do
    member do
      get :status
    end
  end

  # CV Generation routes
  resources :cv_generations do
    member do
      get :status
      post :retry
      post :cancel
      get :download_pdf
      get :view_pdf
      get :preview
      get :preview_resume
      post :save_draft
      post :resume_draft
    end
    collection do
      get :stats
      post :regenerate_all_pdfs # Admin-only action to regenerate all PDFs
      get :count
    end
  end

  # Admin routes
  namespace :admin do
    root "users#index"
    resources :users
    resources :resumes
    resources :cv_generations
    resources :ai_translations
    resources :skills
    resources :work_experiences
    resources :certifications
    resources :educations
    resources :languages

    # Email load testing routes
    resources :email_load_test, only: [ :index ] do
      collection do
        post :start_test
        post :stop_test
        post :cleanup
        get :monitor
        get :results
      end
    end
  end

  # Sidekiq web interface (admin only in production)
  require "sidekiq/web"
  if Rails.env.production?
    # Protect Sidekiq web interface with authentication in production
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => "/sidekiq"
    end
  else
    # Allow access in development/test
    mount Sidekiq::Web => "/sidekiq"
  end

  # LinkedIn Import routes
  get "/linkedin-import", to: "linkedin_imports#new", as: :linkedin_import
  post "/linkedin-import", to: "linkedin_imports#create"
  get "/linkedin-import/:id/status", to: "linkedin_imports#status", as: :linkedin_import_status
  get "/linkedin-import/:id", to: "linkedin_imports#show", as: :linkedin_import_show
  get "/linkedin-import/:id/edit", to: "linkedin_imports#show", as: :linkedin_import_edit
  patch "/linkedin-import/:id", to: "linkedin_imports#update", as: :linkedin_import_update
  post "/linkedin-import/:id/save-to-cv", to: "linkedin_imports#save_to_cv", as: :linkedin_import_save_to_cv
  get "/linkedin-import/:id/download-pdf", to: "linkedin_imports#download_pdf", as: :linkedin_import_download_pdf
  delete "/linkedin-import/:id", to: "linkedin_imports#destroy"

  # CV Import routes (for importing existing CVs)
  post "/cv-import", to: "cv_imports#create", as: :cv_import
  get "/cv-import/:id/status", to: "cv_imports#status", as: :cv_import_status
  get "/cv-import/:id", to: "cv_imports#show", as: :cv_import_show

  # CV Analysis routes
  get "/cv-analysis", to: "cv_analyses#new", as: :cv_analysis
  post "/cv-analysis", to: "cv_analyses#create"
  get "/cv-analysis/:id/status", to: "cv_analyses#status", as: :cv_analysis_status
  get "/cv-analysis/:id", to: "cv_analyses#show", as: :cv_analysis_show

  # Authentication routes
  get "/login", to: "auth#login"
  post "/auth/send_otp", to: "auth#send_otp"
  post "/auth/verify_otp", to: "auth#verify_otp"
  delete "/auth/logout", to: "auth#logout"
  get "/auth/status", to: "auth#status"

  # API routes for AJAX calls
  namespace :api do
    namespace :v1 do
      resources :resumes, only: [ :index, :show ] do
        resources :work_experiences, only: [ :create, :update, :destroy ]
        resources :skills, only: [ :create, :update, :destroy ]
      end
    end

    # Translation API routes
    post "translate_professional_summary", to: "translations#translate_professional_summary"
    post "translate_job_descriptions", to: "translations#translate_job_descriptions"
    get "translation_status/:id", to: "translations#translation_status"
    get "translation_limit", to: "translations#translation_limit"
    get "export_pdf", to: "translations#export_pdf", as: :export_pdf_translations
    post "export_pdf", to: "translations#export_pdf", as: :export_pdf_post_translations
    get "pdf_status", to: "translations#pdf_status", as: :pdf_status_translations
  end
end
