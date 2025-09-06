# WickedPDF configuration
WickedPdf.config = {
  # Path to the wkhtmltopdf executable
  exe_path: Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf'),
  
  # Default options
  page_size: 'A4',
  orientation: 'Portrait',
  margin: {
    top: 20,
    bottom: 20,
    left: 20,
    right: 20
  },
  print_media_type: true,
  disable_smart_shrinking: false,
  encoding: 'UTF-8'
}
