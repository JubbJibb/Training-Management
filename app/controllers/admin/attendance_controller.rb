# frozen_string_literal: true

module Admin
  class AttendanceController < ApplicationController
    layout "admin"
    before_action :set_training_class
    before_action :set_attendance_context, only: [:index]

    def index
      @section = "attendance"
      @tab = params[:tab].presence || "check"
      @attendees_list = load_attendees_for_date_hour
      @existing_record = find_existing_record
      @summary = build_summary
      @edit_mode = params[:edit_record_id].present?
      @edit_record_id = params[:edit_record_id]
      if @tab == "history"
        @history_overview = load_history_overview
        @history_view = params[:history_view].presence || "list"
        @records = load_history_records
        load_history_monthly_data if @history_view == "monthly"
        load_history_student_matrix if @history_view == "student"
      end
    end

    def history_detail
      @record = @training_class.attendance_records.find(params[:record_id])
      @detail_attendees = @record.attendance_record_attendees.includes(attendee: :customer).order("attendees.name")
      render partial: "admin/attendance/attendance_history_detail_frame", layout: false, content_type: "text/html"
    end

    def save
      date = params[:attendance_date].presence
      hour = params[:learning_hour].presence
      record_id = params[:record_id].presence

      if date.blank? || hour.blank?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("attendance_flash", partial: "admin/attendance/flash", locals: { type: :alert, message: "กรุณาเลือกวันที่และชั่วโมงเรียน" }), status: :unprocessable_entity }
          format.html { redirect_to admin_class_workspace_attendance_path(@training_class), alert: "กรุณาเลือกวันที่และชั่วโมงเรียน" }
        end
        return
      end

      attendance_date = Date.parse(date)
      record = if record_id.present?
                 @training_class.attendance_records.find_by(id: record_id)
               else
                 @training_class.attendance_records.find_or_initialize_by(attendance_date: attendance_date, learning_hour: hour)
               end

      record.attendance_date = attendance_date
      record.learning_hour = hour
      record.recorded_by_id = current_user&.id
      record.save!

      attendee_ids_present = (params[:present_ids] || []).map(&:to_i).reject(&:zero?)
      record.attendance_record_attendees.destroy_all
      @training_class.attendees.attendees.find_each do |attendee|
        record.attendance_record_attendees.create!(
          attendee_id: attendee.id,
          present: attendee_ids_present.include?(attendee.id)
        )
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("attendance_flash", partial: "admin/attendance/flash", locals: { type: :notice, message: "บันทึกการเช็กชื่อแล้ว" }),
            turbo_stream.replace("attendance_control_panel", partial: "admin/attendance/attendance_control_panel_wrapper", locals: { training_class: @training_class, existing_record: record, summary: build_summary_for_record(record), attendance_date: record.attendance_date, learning_hour: record.learning_hour }),
            turbo_stream.replace("attendance_summary_cards", partial: "admin/attendance/attendance_summary_cards", locals: { summary: build_summary_for_record(record) })
          ], status: :ok
        end
        format.html { redirect_to admin_class_workspace_attendance_path(@training_class, attendance_date: date, learning_hour: hour), notice: "บันทึกการเช็กชื่อแล้ว" }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("attendance_flash", partial: "admin/attendance/flash", locals: { type: :alert, message: e.message }), status: :unprocessable_entity }
        format.html { redirect_to admin_class_workspace_attendance_path(@training_class), alert: e.message }
      end
    end

    private

    def set_training_class
      @training_class = TrainingClass.find(params[:id])
    end

    def set_attendance_context
      @attendance_date = params[:attendance_date].presence
      @attendance_date = Date.parse(@attendance_date) if @attendance_date.present?
      @learning_hour = params[:learning_hour].presence
    end

    def find_existing_record
      return nil unless @attendance_date && @learning_hour
      @training_class.attendance_records.find_by(attendance_date: @attendance_date, learning_hour: @learning_hour)
    end

    def load_attendees_for_date_hour
      attendees = @training_class.attendees.attendees.includes(:customer).order(:name)
      return attendees.map { |a| { attendee: a, present: false } } unless @attendance_date && @learning_hour
      existing = find_existing_record
      return attendees.map { |a| { attendee: a, present: false } } unless existing
      present_ids = existing.attendance_record_attendees.where(present: true).pluck(:attendee_id)
      attendees.map { |a| { attendee: a, present: present_ids.include?(a.id) } }
    end

    def build_summary
      total = @training_class.attendees.attendees.count
      return { total: total, present: 0, absent: 0, unchecked: total } unless @existing_record
      build_summary_for_record(@existing_record)
    end

    def build_summary_for_record(record)
      total = @training_class.attendees.attendees.count
      present = record.present_count
      absent = record.absent_count
      unchecked = [total - record.attendance_record_attendees.count, 0].max
      { total: total, present: present, absent: absent, unchecked: unchecked }
    end

    def load_history_overview
      tc = @training_class
      end_date = tc.end_date || tc.date
      total_days = (end_date - tc.date).to_i + 1
      records = tc.attendance_records
      recorded_count = records.count
      dates_with_record = records.distinct.pluck(:attendance_date).size
      missing_days = [total_days - dates_with_record, 0].max
      edited_count = records.select(&:edited?).size
      total_attendees = tc.attendees.attendees.count
      avg_rate = if records.any? && total_attendees.positive?
        rates = records.map { |r| (r.present_count.to_f / total_attendees * 100) }
        (rates.sum / rates.size).round(0)
      else
        nil
      end
      {
        total_days: total_days,
        recorded_count: recorded_count,
        missing_count: missing_days,
        edited_count: edited_count,
        avg_attendance_rate: avg_rate
      }
    end

    def load_history_monthly_data
      month_str = params[:month].presence || Date.current.strftime("%Y-%m")
      begin
        start_month = Date.parse("#{month_str}-01")
      rescue ArgumentError
        start_month = Date.current.beginning_of_month
      end
      end_month = start_month.end_of_month
      tc = @training_class
      class_start = [tc.date, start_month].max
      class_end = [tc.end_date || tc.date, end_month].min
      @monthly_start = start_month
      @monthly_end = end_month
      records_by_date = tc.attendance_records
                           .where(attendance_date: start_month..end_month)
                           .includes(:recorded_by)
                           .group_by(&:attendance_date)
      @monthly_days = (start_month..end_month).map do |d|
        in_range = d >= class_start && d <= class_end
        day_records = records_by_date[d] || []
        {
          date: d,
          in_class_range: in_range,
          records: day_records,
          has_record: day_records.any?,
          has_edited: day_records.any?(&:edited?)
        }
      end
    end

    def load_history_student_matrix
      tc = @training_class
      @matrix_attendees = tc.attendees.attendees.includes(:customer).order(:name)
      records = tc.attendance_records.includes(attendance_record_attendees: :attendee)
      @matrix_dates = records.distinct.order(:attendance_date).pluck(:attendance_date)
      @matrix = {}
      records.each do |rec|
        key = [rec.attendance_date, rec.learning_hour]
        @matrix[key] = rec.attendance_record_attendees.where(present: true).pluck(:attendee_id).to_set
      end
      @matrix_record_by_key = records.index_by { |r| [r.attendance_date, r.learning_hour] }
    end

    def load_history_records
      scope = @training_class.attendance_records.includes(:recorded_by).order(attendance_date: :desc, learning_hour: :asc)
      if params[:month].present?
        begin
          start_month = Date.parse("#{params[:month]}-01")
          scope = scope.where(attendance_date: start_month..start_month.end_of_month)
        rescue ArgumentError
          # ignore invalid month
        end
      end
      scope = scope.where(attendance_date: params[:date]) if params[:date].present?
      scope = scope.where(learning_hour: params[:learning_hour]) if params[:learning_hour].present?
      if params[:q].to_s.strip.present?
        q = "%#{params[:q].strip}%"
        scope = scope.joins(attendance_record_attendees: :attendee)
                     .where("attendees.name ILIKE ? OR attendees.email ILIKE ? OR attendees.billing_name ILIKE ?", q, q, q)
                     .distinct
      end
      scope.to_a
    end
  end
end
