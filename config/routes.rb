Rails.application.routes.draw do
  # Health check route for Kamal
  get "/up", to: "application#health_check"

  # Devise routes (for authentication helpers)
  devise_for :users, skip: [ :registrations, :sessions, :passwords, :confirmations, :unlocks ]

  # Root route
  root "home#index"

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
