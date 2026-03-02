# frozen_string_literal: true

module Financials
  # Returns cost totals by standard categories for the Financial Overview.
  # Instructor from TrainingClass.cost; others from ClassExpense.category (mapped from Thai).
  class OverviewCostCompositionQuery
    CATEGORY_MAP = {
      "ค่าเช่าสถานที่" => :venue,
      "ค่าอาหาร" => :food,
      "เครื่องดื่ม" => :food,
      "ค่าขนม" => :food,
      "อุปกรณ์" => :materials,
      "ค่าเดินทาง" => :other,
      "อื่นๆ" => :other
    }.freeze

    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
    end

    def call
      by_cat = { instructor: 0.0, venue: 0.0, food: 0.0, materials: 0.0, other: 0.0 }
      by_cat[:instructor] = instructor_total
      raw = Financials::ExpenseCategoryTotalsQuery.call(@params)
      raw.each do |h|
        key = CATEGORY_MAP[h[:category].to_s] || :other
        by_cat[key] += h[:total].to_f
      end
      total = by_cat.values.sum
      {
        by_category: by_cat,
        total: total,
        rows: [
          { label: "Instructor", amount: by_cat[:instructor] },
          { label: "Venue", amount: by_cat[:venue] },
          { label: "Food", amount: by_cat[:food] },
          { label: "Materials", amount: by_cat[:materials] },
          { label: "Other", amount: by_cat[:other] }
        ]
      }
    end

    private

    def instructor_total
      TrainingClass.where(date: @resolver.start_date..@resolver.end_date).sum(:cost).to_f
    end
  end
end
