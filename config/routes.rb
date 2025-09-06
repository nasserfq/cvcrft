Rails.application.routes.draw do
  # Root route
  root "home#index"

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
    end
  end

  # AI Translation routes
  resources :ai_translations, only: [ :create ] do
    member do
      get :status
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

  # User authentication routes (placeholder for now)
  # get '/login', to: 'sessions#new'
  # post '/login', to: 'sessions#create'
  # delete '/logout', to: 'sessions#destroy'

  # API routes for AJAX calls
  namespace :api do
    namespace :v1 do
      resources :resumes, only: [ :index, :show ] do
        resources :work_experiences, only: [ :create, :update, :destroy ]
        resources :skills, only: [ :create, :update, :destroy ]
      end
    end
    
    # Translation API routes
    post 'translate_professional_summary', to: 'translations#translate_professional_summary'
    get 'translation_status/:id', to: 'translations#translation_status'
    get 'export_pdf', to: 'translations#export_pdf'
    post 'export_pdf', to: 'translations#export_pdf'
  end
end
