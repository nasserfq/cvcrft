class HomeController < ApplicationController
  layout false, only: [:index]

  def index
    # Test Sidekiq job if requested
    if params[:test_sidekiq]
      TestSidekiqJob.perform_async("Hello from CV Craft!")
      flash.now[:notice] = "Sidekiq job queued! Check the logs and Sidekiq dashboard."
    end

    # Show signout notification if user just signed out
    if params[:signed_out] == "true"
      flash.now[:notice] = "تم تسجيل الخروج بنجاح"
    end

    # User count for social proof
    @users_count = User.count
    
    # Load recent CV generations and resumes for logged-in users
    if user_signed_in?
      @recent_cv_generations = current_user.cv_generations.where(status: "completed").recent.limit(3)
      @recent_resumes = current_user.resumes.recent.limit(3)
    end
  end

  def test_sidekiq
    TestSidekiqJob.perform_async("Test message from #{Time.current}")
    redirect_to root_path, notice: "Sidekiq test job queued successfully!"
  end
end
