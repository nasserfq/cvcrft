module AtsStylePresets
  module BridgeToAtsPdfGenerator
    def self.apply!
      return unless defined?(AtsPdfGenerator)

      singleton = AtsPdfGenerator.singleton_class

      singleton.send(:define_method, :template_catalog) do
        AtsStylePresets::AtsStyleCatalog.styles.map do |style|
          { key: style.key, name: style.name, description: style.description }
        end
      end

      singleton.send(:define_method, :normalize_template_key) do |template_key|
        key = template_key.to_s
        catalog = AtsStylePresets::AtsStyleCatalog.styles
        catalog.any? { |style| style.key == key } ? key : catalog.first.key
      end

      singleton.send(:define_method, :template_for) do |template_key|
        styles = AtsStylePresets::AtsStyleCatalog.styles
        styles.find { |style| style.key == template_key } || styles.first
      end
    end
  end
end
