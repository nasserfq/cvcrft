module Admin
  class CvGenerationsController < Admin::ApplicationController
    # POST /admin/cv_generations/regenerate_all_pdfs
    # Rebuilds the PDF of every completed CV generation. Runs synchronously.
    def regenerate_all_pdfs
      result = CvGenerationPdfRegenerator.call
      # The admin area has no locale switching, but I18n.locale is thread-local
      # and can still hold a previous request's value, so pin the default (en).
      redirect_to admin_cv_generations_path,
        notice: t("admin.cv_generations.regenerate_all_pdfs.done",
                  **result.slice(:success, :total, :failed), locale: I18n.default_locale)
    end

    # Overwrite any of the RESTful controller actions to implement custom behavior
    # For example, you may want to send an email after a foo is updated.
    #
    # def update
    #   super
    #   send_foo_updated_email(requested_resource)
    # end

    # Override this method to specify custom lookup behavior.
    # This will be used to set the resource for the `show`, `edit`, and `update`
    # actions.
    #
    # def find_resource(param)
    #   Foo.find_by!(slug: param)
    # end

    # The result of this lookup will be available as `requested_resource`

    # Override this if you have certain roles that require a subset
    # this will be used to set the records shown on the `index` action.
    #
    # def scoped_resource
    #   if current_user.super_admin?
    #     resource_class
    #   else
    #     resource_class.with_less_stuff
    #   end
    # end

    # Override `resource_params` if you want to transform the submitted
    # data before it's persisted. For example, the following would turn all
    # empty values into nil values. It uses other APIs such as `resource_class`
    # and `dashboard`:
    #
    # def resource_params
    #   params.require(resource_class.model_name.param_key).
    #     permit(dashboard.permitted_attributes(action_name)).
    #     transform_values { |value| value == "" ? nil : value }
    # end

    # See https://administrate-demo.herokuapp.com/customizing_controller_actions
    # for more information
  end
end
