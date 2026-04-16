module Admin
  class CustomersController < ApplicationController
    include ActionView::RecordIdentifier

    layout "admin"

    before_action :set_customer, only: [:show, :edit, :update, :sync_document_info, :export_customer_info, :export_billing_accounting, :export_customer_template, :edit_billing_tax, :update_billing_tax, :register_for_class, :bundle_deal_summary, :bundle_deal_register, :attendee_info]

    def index
      @q = params[:q].to_s.strip
      @segment = params[:segment].to_s.presence || "all"
      @top_n = (params[:top_n].presence || Customers::DirectoryQuery::DEFAULT_TOP_N).to_i
      @sort = params[:sort].to_s.presence
      @direction = params[:direction].to_s.downcase == "asc" ? "asc" : "desc"

      query = Customers::DirectoryQuery.new(q: @q, segment: @segment, top_n: @top_n, sort: @sort, direction: @direction)
      @customers = query.call
      @segment = query.segment
    end

    def new
      @customer = Customer.new
    end

    def create
      @customer = Customer.new(customer_params)
      if @customer.save
        redirect_to admin_customer_path(@customer), notice: "สร้างลูกค้าใหม่เรียบร้อย"
      else
        render :new, status: :unprocessable_entity
      end
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

    def merge
      primary = find_customer_param(:primary_email, :primary_id)
      source  = find_customer_param(:source_email, :source_id)
      if primary.blank?
        redirect_to admin_customers_path, alert: "ไม่พบ Customer หลัก (ระบุ primary_email หรือ primary_id)"
        return
      end
      if source.blank?
        redirect_to admin_customers_path, alert: "ไม่พบ Customer ที่จะ merge (ระบุ source_email หรือ source_id)"
        return
      end
      result = CustomerMergeService.new(primary: primary, source: source).call
      if result[:success]
        redirect_to admin_customer_path(primary),
          notice: "Merge แล้ว: ย้ายผู้เข้าร่วม #{result[:attendees_reassigned]} รายการมาที่ #{primary.email}#{result[:attrs_updated].any? ? " (อัปเดตฟิลด์: #{result[:attrs_updated].join(', ')})" : ''}"
      else
        redirect_to admin_customers_path, alert: "Merge ไม่สำเร็จ: #{result[:error]}"
      end
    end

    def sync_document_info
      if request.get?
        redirect_to edit_admin_customer_path(@customer), notice: "ใช้ปุ่ม «Sync from latest registration» เพื่อดึงข้อมูลจากประวัติลงทะเบียน"
        return
      end
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

    def register_for_class
      @upcoming_classes = TrainingClass.upcoming.order(:date).limit(50)
      render :register_for_class
    end

    def bundle_deal_summary
      class_ids = Array(params[:class_ids]).reject(&:blank?).map(&:to_i).uniq
      @training_classes = TrainingClass.upcoming.where(id: class_ids).order(:date).to_a
      if @training_classes.empty?
        redirect_to register_for_class_admin_customer_path(@customer), alert: "กรุณาเลือกอย่างน้อย 1 คลาส"
        return
      end
      @discount_type = params[:discount_type].to_s.presence || "none" # none, percent, fixed, fixed_total
      @discount_value = params[:discount_value].to_s.strip
      discount_num = @discount_value.to_f
      n_classes = @training_classes.size

      # สรุปราคาต่อคลาส (ราคาเริ่มต้นจากคลาส, 1 ที่นั่ง)
      @rows = @training_classes.map do |tc|
        base = (tc.price.to_f || 0).round(2)
        vat_excluded = tc.vat_excluded == true
        discount = 0.0
        if @discount_type == "percent" && discount_num.positive?
          discount = (base * (discount_num / 100)).round(2)
        elsif @discount_type == "fixed" && discount_num.positive?
          discount = 0.0 # แจกตามสัดส่วนหลัง
        end
        before_vat = (base - discount).round(2)
        before_vat = 0.0 if before_vat.negative?
        if vat_excluded
          vat_amount = 0.0
          total = before_vat
        else
          vat_amount = (before_vat * 0.07).round(2)
          total = (before_vat * 1.07).round(2)
        end
        {
          training_class: tc,
          base: base,
          discount: discount,
          before_vat: before_vat,
          vat_amount: vat_amount,
          total: total,
          vat_excluded: vat_excluded
        }
      end

      # ราคา Final รวมทั้ง Bundle: ผู้ใช้กรอกยอดรวมสุดท้าย (รวม VAT) แจกเท่ากันต่อคลาส
      if @discount_type == "fixed_total" && discount_num.positive? && n_classes.positive?
        per_class_total = (discount_num / n_classes).round(2)
        @rows = @training_classes.map do |tc|
          base = (tc.price.to_f || 0).round(2)
          vat_excluded = tc.vat_excluded == true
          if vat_excluded
            before_vat = per_class_total
            vat_amount = 0.0
            total = per_class_total
          else
            before_vat = (per_class_total / 1.07).round(2)
            vat_amount = (per_class_total - before_vat).round(2)
            total = per_class_total
          end
          discount = (base - before_vat).round(2)
          {
            training_class: tc,
            base: base,
            discount: discount,
            before_vat: before_vat,
            vat_amount: vat_amount,
            total: total,
            vat_excluded: vat_excluded
          }
        end
      end

      # ส่วนลดแบบเป็นเงิน: แจกตามสัดส่วนของราคาต่อคลาส
      if @discount_type == "fixed" && discount_num.positive?
        sum_before = @rows.sum { |r| r[:total] + r[:vat_amount] }.round(2)
        sum_before = @rows.sum { |r| r[:base] }.round(2) if sum_before.zero?
        if sum_before.positive?
          remaining = discount_num.round(2)
          @rows.each_with_index do |row, idx|
            if idx == @rows.size - 1
              row[:discount] = remaining
            else
              ratio = row[:base] / sum_before
              row[:discount] = (discount_num * ratio).round(2)
              remaining -= row[:discount]
            end
            row[:before_vat] = (row[:base] - row[:discount]).round(2)
            row[:before_vat] = 0.0 if row[:before_vat].negative?
            if row[:vat_excluded]
              row[:vat_amount] = 0.0
              row[:total] = row[:before_vat]
            else
              row[:vat_amount] = (row[:before_vat] * 0.07).round(2)
              row[:total] = (row[:before_vat] * 1.07).round(2)
            end
          end
        end
      end

      @grand_base = @rows.sum { |r| r[:base] }.round(2)
      @grand_discount = @rows.sum { |r| r[:discount] }.round(2)
      @grand_before_vat = @rows.sum { |r| r[:before_vat] }.round(2)
      @grand_vat = @rows.sum { |r| r[:vat_amount] }.round(2)
      @grand_total = @rows.sum { |r| r[:total] }.round(2)
      render :bundle_deal_summary
    end

    def bundle_deal_register
      class_ids = Array(params[:class_ids]).reject(&:blank?).map(&:to_i).uniq
      training_classes = TrainingClass.upcoming.where(id: class_ids).order(:date).to_a
      if training_classes.empty?
        redirect_to register_for_class_admin_customer_path(@customer), alert: "กรุณาเลือกอย่างน้อย 1 คลาส"
        return
      end
      discount_type = params[:discount_type].to_s.presence || "none"
      discount_value = params[:discount_value].to_s.strip.to_f

      # คำนวณส่วนลดต่อคลาส (fixed = ส่วนลดเป็นเงินแจกตามสัดส่วน, fixed_total = ราคา Final รวมทั้ง Bundle)
      per_class_discounts = {}
      if discount_type == "percent" && discount_value.positive?
        training_classes.each { |tc| per_class_discounts[tc.id] = { percent: discount_value, fixed: nil } }
      elsif discount_type == "fixed" && discount_value.positive?
        sum_base = training_classes.sum { |tc| (tc.price.to_f || 0) }.round(2)
        if sum_base.positive?
          remaining = discount_value.round(2)
          training_classes.each_with_index do |tc, idx|
            if idx == training_classes.size - 1
              per_class_discounts[tc.id] = { percent: nil, fixed: remaining }
            else
              ratio = (tc.price.to_f || 0) / sum_base
              amt = (discount_value * ratio).round(2)
              per_class_discounts[tc.id] = { percent: nil, fixed: amt }
              remaining -= amt
            end
          end
        end
      elsif discount_type == "fixed_total" && discount_value.positive? && training_classes.size.positive?
        # ราคา Final รวมทั้ง Bundle (รวม VAT): แจกเท่ากันต่อคลาส แล้วคำนวณ bundle_discount_fixed = ราคาเดิม - ก่อน VAT ต่อคลาส
        n = training_classes.size
        per_class_total = (discount_value / n).round(2)
        training_classes.each do |tc|
          base = (tc.price.to_f || 0).round(2)
          vat_excluded = tc.vat_excluded == true
          before_vat = vat_excluded ? per_class_total : (per_class_total / 1.07).round(2)
          per_class_discounts[tc.id] = { percent: nil, fixed: (base - before_vat).round(2) }
        end
      else
        training_classes.each { |tc| per_class_discounts[tc.id] = { percent: nil, fixed: nil } }
      end

      created = 0
      errors = []
      training_classes.each do |tc|
        next if tc.attendees.exists?(email: @customer.email)
        d = per_class_discounts[tc.id] || { percent: nil, fixed: nil }
        att = tc.attendees.build(
          name: @customer.name,
          email: @customer.email,
          participant_type: @customer.participant_type.presence || "Indi",
          company: @customer.company,
          customer_id: @customer.id,
          status: "attendee"
        )
        att.bundle_discount_percent = d[:percent] if d[:percent].to_f.positive?
        att.bundle_discount_fixed = d[:fixed] if d[:fixed].to_f.nonzero?
        if att.save
          created += 1
        else
          errors << "#{tc.title}: #{att.errors.full_messages.join(', ')}"
        end
      end
      if created.positive?
        msg = "สมัคร Bundle เรียบร้อย #{created} คลาส"
        msg += " (มีข้อผิดพลาด: #{errors.join('; ')})" if errors.any?
        redirect_to admin_customer_path(@customer), notice: msg
      else
        redirect_to register_for_class_admin_customer_path(@customer), alert: errors.any? ? errors.join("; ") : "ไม่สามารถสมัครได้"
      end
    end

    def attendee_info
      render json: {
        id: @customer.id,
        name: @customer.name.to_s,
        email: @customer.email.to_s,
        phone: @customer.phone.to_s,
        participant_type: @customer.participant_type.presence || "Indi",
        company: @customer.company.to_s,
        tax_id: @customer.tax_id.to_s,
        name_thai: @customer.name_thai.to_s,
        billing_name: @customer.billing_name.to_s,
        address: @customer.address.to_s,
        billing_address: @customer.billing_address.to_s
      }
    end

    def edit_billing_tax
      if params[:close].present?
        render partial: "admin/customers/empty_modal_fragment", layout: false
        return
      end
      render partial: "admin/customers/billing_tax_modal", locals: { customer: @customer }, layout: false
    end

    def update_billing_tax
      if @customer.update(customer_params.slice(:tax_id, :billing_name, :billing_address))
        query = Customers::DirectoryQuery.new(
          q: params[:q].to_s.strip.presence,
          segment: params[:segment].to_s.presence || "all",
          top_n: params[:top_n].presence,
          sort: params[:sort].to_s.presence,
          direction: params[:direction].to_s.downcase == "asc" ? "asc" : "desc"
        )
        rel = query.call
        row_customer = rel.find { |r| r.id == @customer.id } || @customer
        base_params = { q: params[:q].to_s.presence, segment: params[:segment].to_s.presence, top_n: params[:top_n].to_s.presence }.compact
        render turbo_stream: [
          turbo_stream.replace(dom_id(@customer, :row), partial: "admin/customers/row", locals: { customer: row_customer, segment: params[:segment].to_s.presence || "all", sort: params[:sort].to_s.presence, direction: params[:direction].to_s.downcase == "asc" ? "asc" : "desc", base_params: base_params }),
          turbo_stream.replace("modal", partial: "admin/customers/empty_modal_fragment")
        ], status: :ok
      else
        render turbo_stream: turbo_stream.replace("modal", partial: "admin/customers/billing_tax_modal", locals: { customer: @customer }), status: :unprocessable_entity
      end
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def find_customer_param(email_key, id_key)
      email = params[email_key].to_s.strip.downcase.presence
      id = params[id_key].to_s.presence
      if id.present?
        Customer.find_by(id: id)
      elsif email.present?
        Customer.find_by(email: email)
      else
        nil
      end
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
        :name_thai,
        :participant_type,
        :company,
        :email,
        :phone,
        :tax_id,
        :address,
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
