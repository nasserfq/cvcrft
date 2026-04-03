# frozen_string_literal: true

# Programmatic SEO Controller
# Generates dynamic pages for CV templates by job title
class SeoController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  layout false

  before_action :load_seo_data
  before_action :find_job_title, only: [:cv_template]

  # GET /cv-templates
  def cv_templates_index
    @job_titles = @seo_data["job_titles"]
    @categories = @seo_data["categories"]
  end

  # GET /cv-templates/:slug
  def cv_template
    # Set SEO meta data
    @page_title = I18n.locale == :ar ? 
      "قالب سيرة ذاتية #{@job_title['title_ar']} | سيرة" :
      "#{@job_title['title_en']} Resume Template | سيرة"
    
    @meta_description = I18n.locale == :ar ?
      @job_title["description_ar"].strip :
      @job_title["description_en"].strip
    
    @keywords = I18n.locale == :ar ?
      @job_title["keywords_ar"] :
      @job_title["keywords_en"]

    # Get related jobs from same category
    @related_jobs = @seo_data["job_titles"]
      .select { |j| j["category"] == @job_title["category"] && j["slug"] != @job_title["slug"] }
      .first(4)
  end

  private

  def load_seo_data
    @seo_data = YAML.load_file(Rails.root.join("config", "seo_data.yml"))
  end

  def find_job_title
    @job_title = @seo_data["job_titles"].find { |j| j["slug"] == params[:slug] }
    
    unless @job_title
      raise ActionController::RoutingError, "Not Found"
    end
  end
end
