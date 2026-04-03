class PagesController < ApplicationController
  # Skip authentication for static pages
  skip_before_action :authenticate_user!, raise: false
  layout false

  def privacy
  end

  def terms
  end
end
