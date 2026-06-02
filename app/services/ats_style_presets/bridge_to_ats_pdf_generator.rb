module AtsStylePresets
  module BridgeToAtsPdfGenerator
    def self.apply!
      return unless defined?(AtsPdfGenerator)

      singleton = AtsPdfGenerator.singleton_class

      singleton.send(:define_method, :template_catalog) do
        AtsStylePresets::STYLES.map do |style|
          { key: style.key, name: style.name, description: style.description }
        end
      end

      singleton.send(:define_method, :normalize_template_key) do |template_key|
        key = template_key.to_s
        catalog = AtsStylePresets::STYLES
        catalog.any? { |style| style.key == key } ? key : catalog.first.key
      end

      singleton.send(:define_method, :template_for) do |template_key|
        AtsStylePresets::STYLES.find { |style| style.key == template_key } || AtsStylePresets::STYLES.first
      end
    end
  end
end
