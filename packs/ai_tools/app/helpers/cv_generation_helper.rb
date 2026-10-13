module CvGenerationHelper
  def ats_template_options_for_cv_generation
    AtsTemplatePdfService.template_catalog.map do |item|
      key = item[:key]
      {
        key: key,
        name: t("cv_generation.ats.#{key}.name", default: item[:name]),
        description: t("cv_generation.ats.#{key}.description", default: item[:description])
      }
    end
  end
end
