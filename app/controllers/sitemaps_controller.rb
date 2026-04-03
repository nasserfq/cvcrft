class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def index
    base_url = "https://cvcrft.com"
    
    # Core pages
    @pages = [
      { url: base_url, changefreq: 'weekly', priority: 1.0 },
      { url: "#{base_url}/cv-templates", changefreq: 'weekly', priority: 0.9 },
      { url: "#{base_url}/jobs", changefreq: 'weekly', priority: 0.9 },
      { url: "#{base_url}/privacy", changefreq: 'monthly', priority: 0.3 },
      { url: "#{base_url}/terms", changefreq: 'monthly', priority: 0.3 }
    ]
    
    # Load SEO data
    seo_data = YAML.load_file(Rails.root.join('config', 'seo_data.yml'))
    job_titles = seo_data['job_titles']
    cities = seo_data['cities']
    
    # Job title template pages (50 pages)
    job_titles.each do |job|
      @pages << {
        url: "#{base_url}/cv-templates/#{job['slug']}",
        changefreq: 'monthly',
        priority: 0.8
      }
    end
    
    # City landing pages (10 pages)
    cities.each do |city|
      @pages << {
        url: "#{base_url}/jobs/#{city['slug']}",
        changefreq: 'monthly',
        priority: 0.8
      }
    end
    
    # Location-specific job pages (50 jobs × 10 cities = 500 pages)
    cities.each do |city|
      job_titles.each do |job|
        @pages << {
          url: "#{base_url}/cv-templates/#{city['slug']}/#{job['slug']}",
          changefreq: 'monthly',
          priority: 0.7
        }
      end
    end

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
