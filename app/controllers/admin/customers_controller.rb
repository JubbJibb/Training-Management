module Admin
  class CustomersController < ApplicationController
    layout "admin"

    before_action :set_customer, only: [:show, :edit, :update]

    def index
      @q = params[:q].to_s.strip
      @customers = Customer.order(:name)

      if @q.present?
        like = "%#{@q}%"
        @customers = @customers.where(
          "name LIKE :q OR email LIKE :q OR phone LIKE :q OR company LIKE :q OR tax_id LIKE :q",
          q: like
        )
      end

      @customers = @customers.limit(500)
    end

    def show
      @attendees = @customer.attendees.includes(:training_class, :promotions).order(created_at: :desc)

      @registered_classes_count = @customer.classes_attended_count
      @total_registrations = @attendees.attendees.count
      @total_potential = @attendees.potential_customers.count

      @doc_summary = @attendees.attendees.group(:document_status).count
      @payment_summary = @attendees.attendees.group(:payment_status).count
    end

    def edit
    end

    def update
      if @customer.update(customer_params)
        redirect_to admin_customer_path(@customer), notice: "อัปเดตข้อมูลลูกค้าสำเร็จ"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(
        :name,
        :participant_type,
        :company,
        :email,
        :phone,
        :tax_id,
        :billing_name,
        :billing_address
      )
    end
  end
end
