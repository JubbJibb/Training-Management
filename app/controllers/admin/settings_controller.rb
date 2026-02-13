module Admin
  class SettingsController < ApplicationController
    before_action :set_promotion, only: [:edit, :update, :destroy]
    layout "admin"

    def index
      @promotions = Promotion.order(:name)
      @filter_training_classes = TrainingClass.order(date: :desc).limit(50)
      metrics = Promotions::MetricsService.new(period: :this_month)
      @promo_kpi = metrics.kpi_strip
      @promo_performance = metrics.performance_rows
      @promo_highlights = metrics.highlights
      @promo_insights = metrics.insights
      @promo_usage = promotion_usage_counts

      # Marketing dashboard: filters + query
      @perf_query = ::PromotionPerformanceQuery.new(perf_filter_params)
      @perf_kpis = @perf_query.kpis
      @perf_revenue_share = @perf_query.revenue_share
      @perf_leaderboard = @perf_query.leaderboard_rows
      @perf_insights = @perf_query.insights
      @perf_filter_chips = @perf_query.filter_chips
    end

    def promotion_drilldown
      @perf_query = ::PromotionPerformanceQuery.new(perf_filter_params)
      @drilldown = @perf_query.drilldown(params[:id])
      render partial: "admin/settings/perf_drawer", layout: false, content_type: "text/html"
    end

    def promotion_export
      query = ::PromotionPerformanceQuery.new(perf_filter_params)
      require "csv"
      csv = CSV.generate(headers: true) do |rows|
        rows << %w[Rank Name Type Revenue Seats Margin% Discount\ cost Impact]
        query.leaderboard_rows.each_with_index do |r, i|
          rows << [i + 1, r[:name], r[:type_label], r[:revenue], r[:seats], r[:margin_pct], r[:discount_cost], r[:impact_tag]]
        end
      end
      send_data csv, filename: "promotion-performance-#{Date.current}.csv", type: "text/csv"
    end
    
    def new
      @promotion = if params[:clone_from].present?
                     orig = Promotion.find_by(id: params[:clone_from])
                     orig ? Promotion.new(orig.attributes.slice("name", "discount_type", "discount_value", "description", "base_price").merge(active: true)) : Promotion.new
                   else
                     Promotion.new
                   end
    end
    
    def create
      @promotion = Promotion.new(promotion_params)
      
      if @promotion.save
        redirect_to admin_settings_path, notice: "Promotion created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
    end
    
    def update
      if @promotion.update(promotion_params)
        redirect_to admin_settings_path, notice: "Promotion updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @promotion.destroy
      redirect_to admin_settings_path, notice: "Promotion deleted successfully."
    end
    
    private
    
    def set_promotion
      @promotion = Promotion.find(params[:id])
    end

    def promotion_usage_counts
      AttendeePromotion.joins(attendee: :training_class)
                       .where("training_classes.date >= ?", Date.current.beginning_of_month)
                       .group(:promotion_id)
                       .count
    end

    def promotion_params
      params.require(:promotion).permit(:name, :discount_type, :discount_value, :description, :active, :base_price)
    end

    def perf_filter_params
      params.permit(:period, :date_from, :date_to, :course_id, :segment, :channel, :payment_status).to_h
    end
  end
end
