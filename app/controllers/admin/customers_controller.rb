module Admin
  class CustomersController < ApplicationController
    layout "admin"

    before_action :set_customer, only: [:show, :edit, :update, :sync_document_info, :export_customer_info, :export_billing_accounting, :export_customer_template]

    def index
      @q = params[:q].to_s.strip
      @segment = params[:segment].to_s.presence || "all"
      @top_n = (params[:top_n].presence || Customers::DirectoryQuery::DEFAULT_TOP_N).to_i

      query = Customers::DirectoryQuery.new(q: @q, segment: @segment, top_n: @top_n)
      @customers = query.call
      @segment = query.segment
    end

    def show
      # Auto-sync billing/tax from latest registration when customer has missing fields (unless opted out)
      if params[:auto_sync] != "0" && customer_has_missing_billing? && @customer.update_document_info_from_attendees
        @customer.reload
        flash.now[:notice] = "อัปเดตข้อมูลออกเอกสารจากประวัติลงทะเบียนล่าสุดแล้ว"
      end

      @attendees = @customer.attendees.includes(:training_class, :promotions).order(created_at: :desc).to_a
      @attendees_attendees = @customer.attendees.attendees.includes(:training_class).order(created_at: :desc)
      @class_history_limit = params[:limit] == "all" ? 999 : 10
      @class_history_items = @attendees_attendees.limit(@class_history_limit)
      @document_rows = build_document_rows
      @timeline_events = build_timeline_events
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

    def sync_duplicates
      result = CustomerSyncService.new(dry_run: false).call
      redirect_to admin_customers_path,
        notice: "Sync แล้ว: กลุ่มชื่อซ้ำ #{result[:groups_processed]} กลุ่ม, อัปเดต #{result[:customers_updated]} รายการ"
    end

    def sync_document_info
      if @customer.update_document_info_from_attendees
        respond_to do |format|
          format.turbo_stream do
            @attendees = @customer.attendees.includes(:training_class, :promotions).order(created_at: :desc).to_a
            @attendees_attendees = @customer.attendees.attendees.includes(:training_class).order(created_at: :desc)
            @class_history_limit = 10
            @class_history_items = @attendees_attendees.limit(@class_history_limit)
            @document_rows = build_document_rows
            @timeline_events = build_timeline_events
            render :sync_document_info, status: :ok
          end
          format.html { redirect_to admin_customer_path(@customer), notice: "อัปเดตข้อมูลออกเอกสาร (Tax ID / Billing Name / Billing Address) จากประวัติลงทะเบียนแล้ว" }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            flash_target = request.referer.to_s.include?("/edit") ? "customer_edit_flash" : "customer_360_flash"
            render turbo_stream: turbo_stream.update(flash_target, partial: "admin/customers/flash_message", locals: { type: :alert, message: "ไม่มีข้อมูลจากประวัติลงทะเบียนที่ใช้อัปเดตได้" }), status: :unprocessable_entity
          end
          format.html { redirect_to admin_customer_path(@customer), alert: "ไม่มีข้อมูลจากประวัติลงทะเบียนที่ใช้อัปเดตได้" }
        end
      end
    end

    def export_customer_info
      send_customer_csv("customer-info-#{@customer.id}-#{Date.current}.csv", customer_info_headers, customer_info_rows)
    end

    def export_billing_accounting
      send_customer_csv("billing-accounting-#{@customer.id}-#{Date.current}.csv", billing_accounting_headers, billing_accounting_rows)
    end

    def export_customer_template
      send_customer_csv("customer-template-#{@customer.id}-#{Date.current}.csv", customer_template_headers, customer_template_rows)
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def customer_has_missing_billing?
      @customer.tax_id.blank? || @customer.billing_name.blank? || @customer.billing_address.blank?
    end

    def build_document_rows
      @customer.attendees.attendees.includes(:training_class).order("training_classes.date DESC").limit(50).map do |a|
        doc_no = a.receipt_no.presence || a.invoice_no.presence || a.quotation_no.presence || "—"
        {
          doc_type: a.document_status.presence || "—",
          doc_no: doc_no,
          date: a.training_class&.date&.strftime("%d %b %Y") || a.updated_at.strftime("%d %b %Y"),
          amount: a.total_final_price.to_f.round(2),
          status: a.document_status.present? ? "issued" : "missing"
        }
      end
    end

    def build_timeline_events
      list = @customer.attendees.attendees.includes(:training_class).order(created_at: :desc).limit(20)
      events = list.flat_map do |a|
        evs = []
        evs << { label: "Registered: #{a.training_class&.title.presence || 'Class'}", date: a.created_at }
        evs << { label: "Payment: #{a.payment_status}", date: a.updated_at } if a.payment_status.present?
        evs << { label: "Document: #{a.document_status}", date: a.updated_at } if a.document_status.present?
        evs
      end
      events.uniq { |e| [e[:label], e[:date]] }.sort_by { |e| e[:date] }.reverse.take(15).map { |e| e.merge(date: e[:date].strftime("%d %b %Y %H:%M")) }
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

    def send_customer_csv(filename, headers, rows)
      require "csv"
      csv = CSV.generate(headers: true) do |out|
        out << headers
        rows.each { |row| out << row }
      end
      send_data csv, filename: filename, type: "text/csv"
    end

    def customer_info_headers
      %w[email name phone company tax_id billing_name billing_address]
    end

    def customer_info_rows
      c = @customer
      [[c.email, c.name, c.phone.to_s, c.company.to_s, c.tax_id.to_s, c.billing_name.to_s, (c.billing_address.to_s.gsub("\n", " ") rescue c.billing_address.to_s)]]
    end

    def billing_accounting_headers
      %w[Company Tax\ ID Address Contact Email Course Seats Net VAT Total Payment\ Status Document\ Status]
    end

    def billing_accounting_rows
      @customer.attendees.attendees.includes(:training_class).order("training_classes.date DESC").limit(500).map do |a|
        [
          @customer.company_name,
          @customer.tax_id.to_s,
          (@customer.billing_address.to_s.gsub("\n", " ") rescue @customer.billing_address.to_s),
          @customer.contact_person.to_s,
          @customer.email.to_s,
          a.training_class&.title.to_s,
          a.seats.to_i,
          a.total_price_before_vat.to_f.round(2),
          a.total_vat_amount.to_f.round(2),
          a.total_final_price.to_f.round(2),
          a.payment_status.to_s,
          a.document_status.to_s
        ]
      end
    end

    def customer_template_headers
      base = %w[Type Company\ Name Contact\ Person Phone Email Tax\ ID Address Segment Note]
      custom = CustomField.for_entity("customer").pluck(:label)
      base + custom
    end

    def customer_template_rows
      c = @customer
      custom_vals = CustomField.for_entity("customer").map { |cf| CustomFieldValue.find_by(custom_field_id: cf.id, record_type: "Customer", record_id: c.id)&.value.to_s }
      base = [
        c.participant_type.to_s,
        c.company_name.to_s,
        c.name.to_s,
        c.phone.to_s,
        c.email.to_s,
        c.tax_id.to_s,
        (c.billing_address.to_s.gsub("\n", " ") rescue c.billing_address.to_s),
        c.participant_type.to_s,
        ""
      ]
      [base + custom_vals]
    end
  end
end
