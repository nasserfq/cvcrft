class HomeController < ApplicationController
  def index
    # Test Sidekiq job if requested
    if params[:test_sidekiq]
      TestSidekiqJob.perform_async("Hello from CV Craft!")
      flash.now[:notice] = "Sidekiq job queued! Check the logs and Sidekiq dashboard."
    end
  end
  
  def test_sidekiq
    TestSidekiqJob.perform_async("Test message from #{Time.current}")
    redirect_to root_path, notice: "Sidekiq test job queued successfully!"
  end
end
