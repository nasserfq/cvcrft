require "administrate/field/base"

class UserDetailField < Administrate::Field::Base
  def to_s
    return "No user" if data.nil?

    "#{data.name} (#{data.email})"
  end

  def display_resource
    return "No user" if data.nil?

    "#{data.name} (#{data.email})"
  end
end
