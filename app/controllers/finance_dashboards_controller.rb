# frozen_string_literal: true

class FinanceDashboardsController < ApplicationController
  layout "admin"

  def index
    filters = dashboard_filters
    @summary = ::Finance::FinanceDashboardSummary.new(filters).call
    @training_classes = TrainingClass.order(date: :desc).limit(200)
    @channels = Attendee.attendees.where.not(source_channel: [nil, ""]).distinct.pluck(:source_channel).sort

    respond_to do |format|
      format.html
    end
  end

  private

  def dashboard_filters
    preset = params[:preset].presence
    start_d = parse_date(params[:start_date])
    end_d = parse_date(params[:end_date])
    # Default to this month when no date params
    if start_d.blank? && end_d.blank? && preset.blank?
      preset = "this_month"
    end
    {
      start_date: start_d,
      end_date: end_d,
      preset: preset,
      training_class_id: params[:training_class_id].presence&.to_i,
      segment: params[:segment].presence,
      status: params[:status].presence,
      channel: params[:channel].presence
    }.compact
  end

  def parse_date(val)
    return nil if val.blank?
    Date.parse(val)
  rescue ArgumentError
    nil
  end
end
