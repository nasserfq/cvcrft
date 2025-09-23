# WickedPDF configuration
WickedPdf.configure do |config|
  # Path to the wkhtmltopdf executable
  config.exe_path = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
  
  # Default options
  config.page_size = 'A4'
  config.orientation = 'Portrait'
  config.margin = {
    top: 20,
    bottom: 20,
    left: 20,
    right: 20
  }
  config.print_media_type = true
  config.disable_smart_shrinking = false
  config.encoding = 'UTF-8'
end
