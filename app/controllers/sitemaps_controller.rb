class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def index
    base_url = "https://cvcrft.com"
    
    # Core pages
    @pages = [
      { url: base_url, changefreq: 'weekly', priority: 1.0 },
      { url: "#{base_url}/cv-templates", changefreq: 'weekly', priority: 0.9 },
      { url: "#{base_url}/privacy", changefreq: 'monthly', priority: 0.3 },
      { url: "#{base_url}/terms", changefreq: 'monthly', priority: 0.3 }
    ]
    
    # SEO pages - job title templates
    seo_data = YAML.load_file(Rails.root.join('config', 'seo_data.yml'))
    seo_data['job_titles'].each do |job|
      @pages << {
        url: "#{base_url}/cv-templates/#{job['slug']}",
        changefreq: 'monthly',
        priority: 0.8
      }
    end

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
