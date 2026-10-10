# frozen_string_literal: true

# Programmatic SEO Controller
# Generates dynamic pages for CV templates by job title and location
# 50 job titles × 10 cities = 500 location pages + 50 base pages + 10 city pages
class SeoController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  layout false

  before_action :load_seo_data
  before_action :find_job_title, only: [ :cv_template, :cv_template_location ]
  before_action :find_city, only: [ :cv_template_location, :city_jobs ]

  # GET /cv-templates
  def cv_templates_index
    @job_titles = @seo_data["job_titles"]
    @categories = @seo_data["categories"]
  end

  # GET /cv-templates/:slug
  def cv_template
    @job = @job_title
    @categories = @seo_data["categories"]

    # Set SEO meta data
    @page_title = I18n.locale == :ar ?
      "قالب سيرة ذاتية #{@job['title_ar']} | سيرة" :
      "#{@job['title_en']} Resume Template | سيرة"

    @meta_description = I18n.locale == :ar ?
      @job["description_ar"].strip :
      @job["description_en"].strip

    @keywords = I18n.locale == :ar ?
      @job["keywords_ar"] :
      @job["keywords_en"]

    # Get related jobs from same category
    @related_jobs = @seo_data["job_titles"]
      .select { |j| j["category"] == @job["category"] && j["slug"] != @job["slug"] }
      .first(4)
  end

  # GET /cv-templates/:city_slug/:job_slug
  def cv_template_location
    @job = @job_title
    @categories = @seo_data["categories"]
    @cities = @seo_data["cities"]

    # Set location-specific SEO meta data
    city_name = I18n.locale == :ar ? @city["name_ar"] : @city["name_en"]
    job_title = I18n.locale == :ar ? @job["title_ar"] : @job["title_en"]
    country = I18n.locale == :ar ? @city["country_ar"] : @city["country_en"]

    @page_title = I18n.locale == :ar ?
      "قالب سيرة ذاتية #{job_title} في #{city_name} | سيرة" :
      "#{job_title} Resume Template in #{city_name} | سيرة"

    @meta_description = I18n.locale == :ar ?
      "احصل على قالب سيرة ذاتية احترافي لوظيفة #{job_title} في #{city_name}، #{country}. قوالب مُحسّنة لأنظمة ATS وجاهزة للتحميل." :
      "Get a professional #{job_title} resume template for jobs in #{city_name}, #{country}. ATS-optimized templates ready to download."

    @keywords = I18n.locale == :ar ?
      "#{job_title} #{city_name}, سيرة ذاتية #{city_name}, وظائف #{job_title} #{country}" :
      "#{job_title} #{city_name}, #{city_name} resume, #{job_title} jobs #{country}"

    # Get related jobs in same city
    @related_jobs = @seo_data["job_titles"]
      .select { |j| j["category"] == @job["category"] && j["slug"] != @job["slug"] }
      .first(4)

    # Get same job in other cities
    @other_cities = @seo_data["cities"]
      .reject { |c| c["slug"] == @city["slug"] }
      .first(5)
  end

  # GET /jobs/:city_slug (city landing page)
  def city_jobs
    @categories = @seo_data["categories"]
    @job_titles = @seo_data["job_titles"]

    city_name = I18n.locale == :ar ? @city["name_ar"] : @city["name_en"]
    country = I18n.locale == :ar ? @city["country_ar"] : @city["country_en"]

    @page_title = I18n.locale == :ar ?
      "قوالب السيرة الذاتية في #{city_name} | سيرة" :
      "Resume Templates in #{city_name} | سيرة"

    @meta_description = I18n.locale == :ar ?
      "قوالب سيرة ذاتية احترافية لجميع المهن في #{city_name}، #{country}. أكثر من 50 قالب مُحسّن لأنظمة ATS." :
      "Professional resume templates for all professions in #{city_name}, #{country}. 50+ ATS-optimized templates."
  end

  # GET /jobs (all cities index)
  def cities_index
    @cities = @seo_data["cities"]
    @job_count = @seo_data["job_titles"].size

    @page_title = I18n.locale == :ar ?
      "قوالب السيرة الذاتية حسب المدينة | سيرة" :
      "Resume Templates by City | سيرة"

    @meta_description = I18n.locale == :ar ?
      "اختر مدينتك واحصل على قوالب سيرة ذاتية مُحسّنة لسوق العمل المحلي." :
      "Choose your city and get resume templates optimized for the local job market."
  end

  private

  def load_seo_data
    @seo_data = YAML.load_file(Rails.root.join("config", "seo_data.yml"))
  end

  def find_job_title
    slug = params[:job_slug] || params[:slug]
    @job_title = @seo_data["job_titles"].find { |j| j["slug"] == slug }

    unless @job_title
      raise ActionController::RoutingError, "Not Found"
    end
  end

  def find_city
    @city = @seo_data["cities"].find { |c| c["slug"] == params[:city_slug] }

    unless @city
      raise ActionController::RoutingError, "Not Found"
    end
  end
end
