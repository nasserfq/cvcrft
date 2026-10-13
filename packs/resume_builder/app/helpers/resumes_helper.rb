module ResumesHelper
  # Parse date from various formats (text or Date object)
  def parse_date(date_value)
    return nil if date_value.blank?

    if date_value.is_a?(Date) || date_value.is_a?(DateTime) || date_value.is_a?(Time)
      date_value.to_date
    elsif date_value.is_a?(String)
      date_value = date_value.strip
      return nil if date_value.empty?

      begin
        # Handle "YYYY-MM" format (most common in this app)
        if date_value.match?(/^\d{4}-\d{2}$/)
          Date.strptime(date_value, "%Y-%m")
        # Handle "YYYY-MM-DD" format
        elsif date_value.match?(/^\d{4}-\d{2}-\d{2}$/)
          Date.parse(date_value)
        # Handle "MM/YYYY" format
        elsif date_value.match?(/^\d{2}\/\d{4}$/)
          Date.strptime(date_value, "%m/%Y")
        # Handle "YYYY" format
        elsif date_value.match?(/^\d{4}$/)
          Date.new(date_value.to_i, 1, 1)
        else
          Date.parse(date_value)
        end
      rescue ArgumentError, Date::Error
        nil
      end
    else
      nil
    end
  end

  # Format date for display
  def format_date(date_value, format = :month_year)
    date = parse_date(date_value)
    return nil unless date

    case format
    when :month_year
      date.strftime("%m/%Y")
    when :year
      date.strftime("%Y")
    else
      date.strftime("%d/%m/%Y")
    end
  end

  # Get date range display
  def date_range(start_date, end_date, is_current = false, format = :month_year)
    start_str = format_date(start_date, format)

    if is_current
      end_str = "حتى الآن"
    else
      end_str = format_date(end_date, format) || "حتى الآن"
    end

    if start_str.present?
      "#{start_str} - #{end_str}"
    elsif end_str.present?
      end_str
    else
      nil
    end
  end
end
