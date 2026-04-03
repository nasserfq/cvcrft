class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def index
    base_url = "https://cvcrft.com"
    @pages = [
      { url: base_url, changefreq: 'weekly', priority: 1.0 },
      { url: "#{base_url}/privacy", changefreq: 'monthly', priority: 0.3 },
      { url: "#{base_url}/terms", changefreq: 'monthly', priority: 0.3 }
    ]

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end
