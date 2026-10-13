module Admin
  class ApplicationController < Administrate::ApplicationController
    # Credentials come from the environment. No fallback: if ADMIN_PASSWORD is
    # unset the panel gets an unguessable random password for the life of the
    # process, so a misconfiguration locks admins out rather than leaving the
    # dashboard open on a known password.
    http_basic_authenticate_with(
      name: ENV.fetch("ADMIN_USERNAME", "admin"),
      password: ENV.fetch("ADMIN_PASSWORD") { SecureRandom.hex(32) }
    )

    # To customize the behavior of this controller,
    # you can overwrite any of the RESTful actions. For example:
    #
    # def index
    #   super
    #   @resources = User.all
    # end

    # Define a custom finder by overriding the `find_resource` method:
    # def find_resource(param)
    #   User.find_by!(slug: param)
    # end

    # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
    # for more information
  end
end
