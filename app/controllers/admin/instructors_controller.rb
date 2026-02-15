# frozen_string_literal: true

module Admin
  # Lists instructors from training classes (Operations > Instructors).
  class InstructorsController < ApplicationController
    layout "admin"

    def index
      @instructors = TrainingClass.where.not(instructor: [nil, ""])
                                  .distinct
                                  .pluck(:instructor)
                                  .sort
      @classes_by_instructor = TrainingClass.upcoming
                                           .where.not(instructor: [nil, ""])
                                           .group_by(&:instructor)
                                           .transform_values { |classes| classes.size }
    end
  end
end
