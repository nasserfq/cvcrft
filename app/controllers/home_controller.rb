class HomeController < ApplicationController
  def index
    # Test Sidekiq job if requested
    if params[:test_sidekiq]
      TestSidekiqJob.perform_async("Hello from CV Craft!")
      flash.now[:notice] = "Sidekiq job queued! Check the logs and Sidekiq dashboard."
    end
    
    # Show signout notification if user just signed out
    if params[:signed_out] == 'true'
      flash.now[:notice] = "تم تسجيل الخروج بنجاح"
    end
  end
  
  def test_sidekiq
    TestSidekiqJob.perform_async("Test message from #{Time.current}")
    redirect_to root_path, notice: "Sidekiq test job queued successfully!"
  end
end
