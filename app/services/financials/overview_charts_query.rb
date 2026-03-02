# frozen_string_literal: true

module Financials
  class OverviewChartsQuery
    class << self
      def call(params = {})
        new(params).call
      end
    end

    def initialize(params = {})
      @params = params
      @resolver = Financials::DateRangeResolver.new(params)
      @attendees = build_attendees_scope
    end

    def call
      {
        revenue_by_class: revenue_by_class,
        revenue_by_channel: revenue_by_channel,
        corporate_vs_individual: corporate_vs_individual
      }
    end

    private

    def build_attendees_scope
      scope = Attendee.attendees.joins(:training_class).where(training_classes: { date: @resolver.start_date..@resolver.end_date })
      scope = scope.where(participant_type: @params[:client_type]) if @params[:client_type].in?(%w[Indi Corp])
      scope = scope.where(payment_status: @params[:status]) if @params[:status].in?(%w[Pending Paid])
      scope.includes(:training_class, :customer)
    end

    def revenue_by_class
      @attendees.group_by(&:training_class_id).transform_values do |list|
        list.sum { |a| (a.payment_status == "Paid" ? (a.total_final_price || 0) : 0) }
      end.map { |tc_id, total| { class_id: tc_id, class_title: TrainingClass.find_by(id: tc_id)&.title, total: total } }.sort_by { |h| -h[:total] }.first(15)
    end

    def revenue_by_channel
      @attendees.group_by { |a| a.source_channel.presence || "Direct" }.transform_values do |list|
        list.sum { |a| (a.payment_status == "Paid" ? (a.total_final_price || 0) : 0) }
      end.map { |channel, total| { channel: channel, total: total } }
    end

    def corporate_vs_individual
      indi = @attendees.select { |a| a.participant_type == "Indi" }.sum { |a| (a.payment_status == "Paid" ? (a.total_final_price || 0) : 0) }
      corp = @attendees.select { |a| a.participant_type == "Corp" }.sum { |a| (a.payment_status == "Paid" ? (a.total_final_price || 0) : 0) }
      [{ segment: "Individual", total: indi }, { segment: "Corporate", total: corp }]
    end
  end
end
