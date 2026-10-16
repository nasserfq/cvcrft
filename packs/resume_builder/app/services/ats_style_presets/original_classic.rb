module AtsStylePresets
  class OriginalClassic < Base
    def self.key = "original_classic"
    def self.display_name = "Original Classic (Legacy)"
    def self.description = "Your previous default ATS template style"

    def self.legacy_template = "classic_01"
  end
end
