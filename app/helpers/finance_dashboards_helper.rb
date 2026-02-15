# frozen_string_literal: true

module FinanceDashboardsHelper
  # Maps overview health_status (excellent/good/fair/poor) to banner variant and label.
  # Returns { variant: "green"|"yellow"|"red", label: String }
  def finance_health_banner_options(health_status)
    case health_status.to_s
    when "excellent", "good"
      { variant: "green", label: "Financial health: #{health_status.to_s.titleize}" }
    when "fair"
      { variant: "yellow", label: "Financial health: Fair — review collection and overdue" }
    when "poor"
      { variant: "red", label: "Financial health: Needs attention" }
    else
      { variant: "neutral", label: "Financial health: —" }
    end
  end
end
