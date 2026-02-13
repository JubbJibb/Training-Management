# frozen_string_literal: true

module Admin
  class CoursesController < ApplicationController
    layout "admin"
    before_action :set_course, only: [:show, :edit, :update]

    def index
      @courses = Course.by_title
      @last_synced = Course.where.not(synced_at: nil).maximum(:synced_at)
    end

    def show
    end

    def edit
    end

    def update
      if @course.update(course_params)
        redirect_to admin_course_path(@course), notice: "Course updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def sync
      result = OdtsCoursesFetcherService.call
      redirect_to admin_courses_path, notice: "Synced #{result[:count]} courses from ODT."
    rescue OdtsCoursesFetcherService::FetchError => e
      redirect_to admin_courses_path, alert: "Sync failed: #{e.message}"
    end

    private

    def set_course
      @course = Course.find(params[:id])
    end

    def course_params
      params.require(:course).permit(:title, :description, :capacity, :duration_text, :category, :source_url)
    end
  end
end
