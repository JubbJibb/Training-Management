# frozen_string_literal: true

module Public
  class ClassesController < ApplicationController
    layout "application"
    skip_before_action :verify_authenticity_token, only: [:show]
    before_action :set_training_class, only: [:show]

    def show
      return render "disabled", status: :not_found unless @training_class.public_enabled?
    end

    private

    def set_training_class
      @training_class = TrainingClass.find_by(public_slug: params[:public_slug])
      raise ActiveRecord::RecordNotFound unless @training_class
    end
  end
end
