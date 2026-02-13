module Admin
  class AttendeesController < ApplicationController
    before_action :set_training_class
    before_action :set_attendee, only: [:show, :edit, :update, :destroy, :move_to_potential, :move_to_attendee, :sync_tax_from_customer]
    skip_before_action :set_attendee, only: [:index, :new, :create, :export, :export_documents]
    skip_before_action :verify_authenticity_token, only: [:update], if: :document_modal_update?
    layout "admin"
    
    def index
      @attendees = @training_class.attendees.order(:name)
    end
    
    def show
      redirect_to edit_admin_training_class_attendee_path(@training_class, @attendee)
    end
    
    def new
      @attendee = @training_class.attendees.build
      if params[:customer_id].present?
        customer = Customer.find_by(id: params[:customer_id])
        if customer
          @attendee.name = customer.name
          @attendee.email = customer.email
          @attendee.participant_type = customer.participant_type.presence || "Indi"
          @attendee.company = customer.company
          @attendee.customer_id = customer.id
        end
      end
      @promotions = Promotion.active.order(:name)
    end
    
    def create
      @attendee = @training_class.attendees.build(attendee_params)
      
      if @attendee.save
        redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee added successfully."
      else
        @promotions = Promotion.active.order(:name)
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      @promotions = Promotion.active.order(:name)
    end
    
    def update
      unless params[:attendee].present?
        redirect_back fallback_location: admin_training_class_path(@training_class), alert: "No data to update."
        return
      end
      p = attendee_params
      p = p.except(:document_modal) # sentinel from document modal form
      # ดึงเฉพาะไฟล์ใหม่ที่อัปโหลดจริง (ไม่ส่ง payment_slips เข้า update เพื่อไม่ให้สลิปเดิมถูกลบ)
      new_slips = extract_new_payment_slip_files(p[:payment_slips])
      p = p.except(:payment_slips)
      if @attendee.update(p)
        # ถ้ามีไฟล์ใหม่ให้แนบเพิ่ม (ไม่แทนที่ของเดิม)
        @attendee.payment_slips.attach(new_slips) if new_slips.present?
        if params[:redirect_tab].present?
          redirect_to admin_training_class_path(@training_class, tab: params[:redirect_tab]), notice: "#{@attendee.name} updated successfully."
        elsif params[:quick_edit]
          redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: "#{@attendee.name} updated successfully."
        else
          redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee updated successfully."
        end
      else
        if params[:redirect_tab].present?
          redirect_to admin_training_class_path(@training_class, tab: params[:redirect_tab]), alert: "Error: #{@attendee.errors.full_messages.join(', ')}"
        elsif params[:quick_edit]
          redirect_to admin_training_class_path(@training_class, tab: "attendees"), alert: "Error: #{@attendee.errors.full_messages.join(', ')}"
        else
          @promotions = Promotion.active.order(:name)
          render :edit, status: :unprocessable_entity
        end
      end
    end
    
    def destroy
      @attendee.destroy
      redirect_to admin_training_class_attendees_path(@training_class), notice: "Attendee removed successfully."
    end
    
    def move_to_potential
      @attendee.update(status: "potential")
      redirect_to admin_training_class_path(@training_class, tab: "potential"), notice: "#{@attendee.name} has been moved to Potential Customers. All information has been preserved."
    end
    
    def move_to_attendee
      if request.get?
        redirect_to admin_training_class_path(@training_class, tab: "potential"), notice: "Please use the 'Move to Attendees' button to convert this person to an attendee."
        return
      end
      @attendee.update(status: "attendee")
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: "#{@attendee.name} has been moved to Class Attendees. All information has been preserved."
    end
    
    def sync_tax_from_customer
      @attendee.sync_document_info_from_customer
      if @attendee.save
        render turbo_stream: turbo_stream.replace("attendee_tax_cell_#{@attendee.id}", partial: "admin/attendees/billing_tax_icons", locals: { attendee: @attendee, training_class: @training_class }), status: :ok
      else
        head :unprocessable_entity
      end
    end

    def send_email
      email_type = params[:email_type] || "class_info"
      
      case email_type
      when "class_info"
        AttendeeMailer.send_class_info(@attendee).deliver_now
        message = "Class information email sent to #{@attendee.email}"
      when "reminder"
        AttendeeMailer.send_reminder(@attendee).deliver_now
        message = "Reminder email sent to #{@attendee.email}"
      when "custom"
        subject = params[:subject]
        body = params[:message]
        AttendeeMailer.send_custom(@attendee, subject, body).deliver_now
        message = "Custom email sent to #{@attendee.email}"
      else
        message = "Invalid email type"
      end
      
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), notice: message
    rescue => e
      redirect_to admin_training_class_path(@training_class, tab: "attendees"), alert: "Error sending email: #{e.message}"
    end
    
    def export
      @attendees = @training_class.attendees.order(:name)
      
      respond_to do |format|
        format.csv do
          headers['Content-Disposition'] = "attachment; filename=\"#{@training_class.title.parameterize}-attendees-#{Date.today}.csv\""
          headers['Content-Type'] ||= 'text/csv'
        end
      end
    end

    # Export selected attendees to Excel with selected fields (from Documents tab)
    def export_documents
      ids = Array(params[:attendee_ids]).reject(&:blank?).map(&:to_i)
      attendees = @training_class.attendees.where(id: ids).order(:name).includes(:training_class, :promotions).with_attached_payment_slips
      columns = Array(params[:columns]).reject(&:blank?).map(&:to_s)
      columns = %w[name email company class_name unit_price discount vat final_price document_status quotation_no invoice_no receipt_no payment_slip name_thai tax_id address amount payment_date] if columns.empty?

      allowed = %w[name email company class_name unit_price discount vat final_price document_status quotation_no invoice_no receipt_no payment_slip name_thai tax_id address amount payment_date]
      columns = columns & allowed

      xlsx = build_documents_xlsx(attendees, columns)
      filename = "documents-#{@training_class.title.parameterize}-#{Date.current.iso8601}.xlsx"
      send_data xlsx, filename: filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", disposition: "attachment"
    end

    private

    DOCUMENT_EXPORT_LABELS = {
      "name" => "Name", "email" => "Email", "company" => "Company",
      "name_thai" => "Name (Thai)", "tax_id" => "Tax ID", "address" => "Address",
      "class_name" => "Class", "unit_price" => "ราคา/หัว", "discount" => "ส่วนลด", "vat" => "VAT", "final_price" => "ราคา Final",
      "document_status" => "Document status", "quotation_no" => "Quotation no", "invoice_no" => "Invoice no",
      "receipt_no" => "Receipt no", "payment_slip" => "Payment slip",
      "amount" => "Amount", "payment_date" => "Payment Date"
    }.freeze

    def build_documents_xlsx(attendees, columns)
      require "caxlsx"
      tempfiles = []
      p = Axlsx::Package.new
      slip_col_index = columns.index("payment_slip")
      p.workbook.add_worksheet(name: "Documents") do |sheet|
        sheet.add_row columns.map { |c| DOCUMENT_EXPORT_LABELS[c.to_s] || c.humanize }, style: sheet.workbook.styles.add_style(b: true)
        attendees.each do |a|
          row = columns.map { |c| document_export_value(a, c) }
          sheet.add_row row
        end
        # Embed payment slip images in Excel when payment_slip column is present
        if slip_col_index && slip_col_index >= 0
          attendees.each_with_index do |a, idx|
            next unless a.payment_slips.attached?
            row_index = 1 + idx
            row = sheet.rows[row_index]
            next unless row
            a.payment_slips.each do |blob|
              next unless blob.content_type&.start_with?("image/")
              ext = blob.filename.respond_to?(:extension_with_delimiter) ? blob.filename.extension_with_delimiter : File.extname(blob.filename.to_s)
              ext = ".png" if ext.blank?
              temp = Tempfile.new(["slip", ext])
              temp.binmode
              temp.write(blob.download)
              temp.close
              tempfiles << temp
              sheet.add_image(image_src: temp.path, noSelect: true, noMove: true) do |img|
                img.start_at(slip_col_index, row_index)
                img.width = 120
                img.height = 90
              end
              row.height = 90
              break
            end
          end
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      p.to_stream.read
    ensure
      tempfiles.each { |t| t.unlink if t.respond_to?(:unlink) }
    end

    def document_export_value(a, col)
      case col.to_s
      when "name" then a.name
      when "email" then a.email
      when "company" then a.company.presence || "—"
      when "class_name" then a.training_class.title.to_s
      when "unit_price" then a.base_price.to_f.round(2)
      when "discount" then (a.total_discount_amount * (a.seats || 1)).round(2)
      when "vat" then a.total_vat_amount.to_f.round(2)
      when "final_price" then a.total_amount.to_f.round(2)
      when "document_status" then a.document_status.presence || "—"
      when "quotation_no" then a.quotation_no.presence || "—"
      when "invoice_no" then a.invoice_no.presence || "—"
      when "receipt_no" then a.receipt_no.presence || "—"
      when "payment_slip" then a.payment_slips.attached? ? a.payment_slips.map(&:filename).join("; ") : "—"
      when "name_thai" then a.name_thai.presence || "—"
      when "tax_id" then a.tax_id.presence || a.customer&.tax_id.to_s.presence || "—"
      when "address" then (a.respond_to?(:document_billing_address) ? a.document_billing_address : a.address).to_s.gsub(/\n/, " ").presence || "—"
      when "amount" then a.total_amount.to_f
      when "payment_date" then (a.respond_to?(:display_payment_date) && a.display_payment_date.present? ? a.display_payment_date.to_s : "—")
      else ""
      end
    end
    
    def set_training_class
      @training_class = TrainingClass.find(params[:training_class_id])
    end
    
    def set_attendee
      @attendee = @training_class.attendees.find(params[:id])
    end

    # Document tab modal submits with redirect_tab=documents; avoid CSRF issues from dynamic form action.
    def document_modal_update?
      params[:redirect_tab] == "documents" && params[:attendee].is_a?(ActionController::Parameters)
    end

    # คืนเฉพาะไฟล์ที่อัปโหลดจริง (ไม่รวมค่าว่างหรือ string) เพื่อไม่ให้ Active Storage แทนที่สลิปเดิม
    def extract_new_payment_slip_files(slips_param)
      return [] if slips_param.blank?
      Array(slips_param).select { |f| f.respond_to?(:tempfile) && f.tempfile.present? }
    end

    def attendee_params
      params.require(:attendee).permit(:name, :email, :phone, :company, :notes,
                                        :participant_type, :seats, :source_channel, :payment_status, :payment_date,
                                        :document_status, :attendance_status, :total_classes, :price,
                                        :quotation_no, :invoice_no, :receipt_no, :due_date, :status,
                                        :name_thai, :tax_id, :address, :billing_name, :billing_address,
                                        :document_modal,
                                        promotion_ids: [], payment_slips: [])
    end
  end
end
