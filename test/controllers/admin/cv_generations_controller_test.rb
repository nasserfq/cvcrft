require "test_helper"

class Admin::CvGenerationsControllerTest < ActionDispatch::IntegrationTest
  test "regenerate_all_pdfs without Basic auth is refused" do
    CvGenerationPdfRegenerator.expects(:call).never

    # The IntegrationTest helpers add Basic auth to every request; go through
    # the session directly to send none.
    integration_session.post "/admin/cv_generations/regenerate_all_pdfs"

    assert_equal 401, integration_session.response.status
  end

  test "regenerate_all_pdfs with Basic auth runs the regenerator and redirects with the counts" do
    CvGenerationPdfRegenerator.expects(:call).once.returns({ total: 5, success: 3, failed: 2 })

    post "/admin/cv_generations/regenerate_all_pdfs"

    assert_redirected_to "/admin/cv_generations"
    assert_equal "PDF regeneration complete: 3/5 successful, 2 failed", flash[:notice]
  end
end
