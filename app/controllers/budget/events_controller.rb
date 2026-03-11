# frozen_string_literal: true

module Budget
  class EventsController < Budget::BaseController
    before_action :set_event, only: [:show, :edit, :update]

    def index
      @events = Budget::Event.by_start_date
    end

    def show
      @sponsorship_deals = @event.sponsorship_deals
    end

    def new
      @event = Budget::Event.new
    end

    def create
      @event = Budget::Event.new(event_params)
      if @event.save
        redirect_to budget_event_path(@event), notice: "Event created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @event.update(event_params)
        redirect_to budget_event_path(@event), notice: "Event updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_event
      @event = Budget::Event.find(params[:id])
    end

    def event_params
      params.require(:budget_event).permit(:name, :organizer, :start_date, :end_date, :location, :objective, :owner_name, :notes)
    end
  end
end
