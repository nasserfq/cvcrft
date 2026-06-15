module ApplicationHelper
  def random_coupon_code_placeholder
    SecureRandom.alphanumeric(8).upcase
  end
end
