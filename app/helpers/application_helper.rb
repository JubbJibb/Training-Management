module ApplicationHelper
  def number_with_delimiter(number, options = {})
    delimiter = options[:delimiter] || ","
    separator = options[:separator] || "."
    
    parts = number.to_s.split(".")
    parts[0] = parts[0].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    parts.join(separator)
  end
end
