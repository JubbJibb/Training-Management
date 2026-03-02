# frozen_string_literal: true

require "ostruct"

module Admin
  class ClassWorkspaceController < ApplicationController
    layout "admin"
    before_action :set_training_class

    def show
      redirect_to admin_class_workspace_overview_path(@training_class), status: :found
    end

    def overview
      @section = "overview"
      load_overview_data
      load_finance_data
    end

    def attendees
      @section = "attendees"
      scope = @training_class.attendees.attendees.includes(:customer).order(:name)
      list = filter_attendees_by_params(scope.to_a)
      @attendees = sort_attendees(list)
      @sort_column = params[:sort].presence || "name"
      @sort_direction = params[:direction].presence == "desc" ? "desc" : "asc"
    end

    def leads
      @section = "leads"
      scope = @training_class.attendees.potential_customers
      list = scope.order(:name).to_a
      @leads = sort_leads(list)
      @leads_sort_column = params[:sort].presence || "name"
      @leads_sort_direction = params[:direction].presence == "desc" ? "desc" : "asc"
      load_leads_kanban
    end

    def documents
      @section = "documents"
      load_documents_data
      scope = @training_class.attendees.attendees.includes(:customer).order(:name)
      @attendees = sort_attendees(scope.to_a)
      @sort_column = params[:sort].presence || "name"
      @sort_direction = params[:direction].presence == "desc" ? "desc" : "asc"
    end

    def finance
      @section = "finance"
      load_finance_data
    end

    def edit
      @section = "edit"
    end

    def update_checklist
      raw = params[:checklist_items] || params.dig(:class_workspace, :checklist_items) || []
      items = raw.is_a?(Hash) ? raw.values : Array(raw)
      valid_items = items.filter_map do |item|
        h = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h
        title = (h["title"] || h[:title]).to_s.strip
        next if title.blank?
        {
          "id" => (h["id"] || h[:id]).presence || SecureRandom.uuid,
          "title" => title,
          "done" => ActiveModel::Type::Boolean.new.cast(h["done"] || h[:done] || false),
          "created_at" => (h["created_at"] || h[:created_at]).presence || Time.current.iso8601,
          "updated_at" => Time.current.iso8601
        }
      end
      @training_class.update!(checklist_items: valid_items)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("workspace-checklist", partial: "admin/class_workspace/sections/overview_checklist", locals: { training_class: @training_class }), status: :ok
      else
        redirect_to admin_class_workspace_overview_path(@training_class), notice: "Checklist updated."
      end
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_class_workspace_overview_path(@training_class), alert: "Failed to update checklist."
    end

    def update_public
      enabled = ActiveModel::Type::Boolean.new.cast(params[:public_enabled])
      @training_class.update!(public_enabled: enabled)
      if enabled && @training_class.public_slug.blank?
        @training_class.ensure_public_slug!
      end
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("workspace-public-block", partial: "admin/class_workspace/shared/public_link_block", locals: { training_class: @training_class }),
            turbo_stream.replace("workspace-public-section", partial: "admin/class_workspace/sections/public_page_section", locals: { training_class: @training_class }),
            turbo_stream.replace("workspace-overview-public-status", partial: "admin/class_workspace/sections/overview/public_status_row", locals: { training_class: @training_class })
          ], status: :ok
        end
        format.html { redirect_to admin_class_workspace_overview_path(@training_class), notice: enabled ? "Public page enabled." : "Public page disabled." }
      end
    end

    def update_notes
      @training_class.assign_attributes(
        internal_notes: params[:internal_notes].to_s,
        internal_notes_updated_at: Time.current,
        internal_notes_updated_by_id: current_user&.id
      )
      @training_class.save!
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workspace-notes-card", partial: "admin/class_workspace/sections/overview_notes_card", locals: { training_class: @training_class }), status: :ok }
        format.html { redirect_to admin_class_workspace_overview_path(@training_class), notice: "Notes saved." }
      end
    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workspace-notes-errors", partial: "admin/class_workspace/sections/overview_notes_errors", locals: { errors: @training_class.errors.full_messages }), status: :unprocessable_entity }
        format.html { redirect_to admin_class_workspace_overview_path(@training_class), alert: "Failed to save notes." }
      end
    end

    private

    def set_training_class
      @training_class = TrainingClass.find(params[:id])
    end

    def load_overview_data
      @attendees = @training_class.attendees.attendees.includes(:customer)
      @leads_count = @training_class.attendees.potential_customers.count
      @capacity = @training_class.max_attendees.to_i
      @confirmed = @training_class.total_registered_seats
      @revenue = @training_class.net_revenue
      # Ensure default checklist items exist
      @checklist_items = default_checklist_items(@training_class)
    end

    def default_checklist_items(tc)
      defaults = [
        "Venue booked", "Slides ready", "Food confirmed",
        "Name list printed", "Certificates prepared", "Invoice issued"
      ]
      existing = tc.checklist_items.presence || []
      existing_titles = existing.map { |i| i["title"].to_s }.compact
      missing = defaults - existing_titles
      out = existing.dup
      missing.each do |title|
        out << {
          "id" => SecureRandom.uuid,
          "title" => title,
          "done" => false,
          "created_at" => Time.current.iso8601,
          "updated_at" => Time.current.iso8601
        }
      end
      out
    end

    def load_leads_kanban
      all = @training_class.attendees.potential_customers.order(:created_at).to_a
      @leads_by_stage = {
        interested: all,
        contacted: [],
        deciding: [],
        confirmed: [],
        lost: []
      }
    end

    def load_documents_data
      @document_summary = DocumentSummaryService.new(@training_class.id).summary
      @generated = {
        quotations: @document_summary&.dig(:quotations) || {},
        invoices: @document_summary&.dig(:invoices) || {},
        receipts: @document_summary&.dig(:receipts) || {},
        certificate_list: { label: "Certificate list", count: 0, action: "download", action_label: "Download" }
      }
      @uploaded = { po: [], withholding_tax: [], transfer_slip: [] }
    end

    def filter_attendees_by_params(list)
      list = list.select { |a| a.participant_type == "Corp" } if params[:tab] == "corporate"
      list = list.select { |a| a.participant_type != "Corp" } if params[:tab] == "individual"
      list = list.select { |a| a.payment_status == "Paid" } if params[:payment] == "paid"
      list = list.select { |a| a.payment_status != "Paid" } if params[:payment] == "pending"
      list = list.select { |a| overdue?(a) } if params[:payment] == "overdue"
      list = list.select { |a| a.payment_status == "Refunded" } if params[:payment] == "refunded"
      list = list.select { |a| (a.source_channel || "").downcase == (params[:source] || "").downcase } if params[:source].present?
      if params[:q].to_s.strip.present?
        q = params[:q].to_s.strip.downcase
        list = list.select { |a| (a.name.to_s + " " + a.company.to_s + " " + a.email.to_s).downcase.include?(q) }
      end
      list
    end

    SORTABLE_ATTENDEE_COLUMNS = %w[name participant_type seats source_channel payment_status payment_date amount].freeze

    def sort_attendees(list)
      sort = params[:sort].presence
      return list unless sort.in?(SORTABLE_ATTENDEE_COLUMNS)

      direction = params[:direction].presence == "desc" ? -1 : 1
      list.sort do |a, b|
        va = sort_value(a, sort)
        vb = sort_value(b, sort)
        cmp = compare_for_sort(va, vb)
        cmp * direction
      end
    end

    def sort_value(attendee, column)
      case column
      when "name" then (attendee.name || "").downcase
      when "participant_type" then (attendee.participant_type || "").downcase
      when "seats" then attendee.seats.to_i
      when "source_channel" then (attendee.source_channel || "").downcase
      when "payment_status" then (attendee.payment_status || "").downcase
      when "payment_date"
        d = attendee.respond_to?(:payment_date) && attendee.payment_date.present? ? attendee.payment_date.to_date : nil
        d ? d.to_time.to_i : 0
      when "amount" then attendee.respond_to?(:total_final_price) ? attendee.total_final_price.to_f : 0.0
      else (attendee.name || "").downcase
      end
    end

    def compare_for_sort(a, b)
      if a.is_a?(Numeric) && b.is_a?(Numeric)
        a <=> b
      elsif a.is_a?(String) && b.is_a?(String)
        a <=> b
      else
        a.to_s <=> b.to_s
      end
    end

    LEADS_SORTABLE_COLUMNS = %w[name participant_type seats source_channel created_at].freeze

    def sort_leads(list)
      sort = params[:sort].presence
      return list unless sort.in?(LEADS_SORTABLE_COLUMNS)

      direction = params[:direction].presence == "desc" ? -1 : 1
      list.sort do |a, b|
        va = lead_sort_value(a, sort)
        vb = lead_sort_value(b, sort)
        cmp = compare_for_sort(va, vb)
        cmp * direction
      end
    end

    def lead_sort_value(lead, column)
      case column
      when "name" then (lead.name || "").downcase
      when "participant_type" then (lead.participant_type || "").downcase
      when "seats" then lead.seats.to_i
      when "source_channel" then (lead.source_channel || "").downcase
      when "created_at" then (lead.created_at&.to_i || 0)
      else (lead.name || "").downcase
      end
    end

    def overdue?(attendee)
      return false if attendee.payment_status == "Paid"
      attendee.respond_to?(:due_date) && attendee.due_date.present? && attendee.due_date < Time.zone.today
    end

    def load_finance_data
      attendees = @training_class.attendees.attendees
      expected_revenue = attendees.sum(&:total_final_price)
      paid_revenue = attendees.select { |a| a.payment_status == "Paid" }.sum(&:total_final_price)
      outstanding_revenue = expected_revenue - paid_revenue
      @class_expenses = @training_class.class_expenses.order(expense_date: :desc, created_at: :desc)

      cost_instructor = @training_class.cost.to_f
      cost_other = @class_expenses.sum(&:amount)
      paid_costs = cost_instructor + @class_expenses.select { |e| e.payment_status == "paid" }.sum(&:amount)
      unpaid_costs = @class_expenses.reject { |e| e.payment_status == "paid" }.sum(&:amount)
      total_costs = @training_class.total_cost.to_f
      price_per_seat = (@training_class.price.to_f > 0) ? @training_class.price.to_f : 0
      break_even_seats = (price_per_seat.positive? && total_costs.positive?) ? (total_costs / price_per_seat).ceil : nil
      break_even_amount = total_costs
      profit_paid = paid_revenue - total_costs
      profit_expected = expected_revenue - total_costs
      margin_paid = paid_revenue.positive? ? ((profit_paid / paid_revenue) * 100).round(1) : 0
      margin_expected = expected_revenue.positive? ? ((profit_expected / expected_revenue) * 100).round(1) : 0

      total_attendees = attendees.size
      invoice_issued = attendees.count { |a| a.invoice_no.present? }
      receipt_issued = attendees.count { |a| a.receipt_no.present? }
      quotation_issued = attendees.count { |a| a.quotation_no.present? }
      @docs_summary = {
        invoice_issued_count: invoice_issued,
        invoice_needed_count: total_attendees,
        receipt_issued_count: receipt_issued,
        receipt_needed_count: total_attendees,
        quotation_issued_count: quotation_issued,
        quotation_needed_count: total_attendees,
        missing_invoice_count: [total_attendees - invoice_issued, 0].max,
        missing_receipt_count: [total_attendees - receipt_issued, 0].max,
        missing_quotation_count: [total_attendees - quotation_issued, 0].max
      }

      today = Date.current
      receivables_raw = attendees.reject { |a| a.payment_status == "Paid" }.map do |a|
        due = a.respond_to?(:due_date) ? a.due_date : nil
        days = due ? (today - due).to_i : 0
        bucket = days <= 7 ? :bucket_0_7 : (days <= 30 ? :bucket_8_30 : :bucket_30_plus)
        {
          id: a.id,
          customer_name: a.name,
          amount: a.total_final_price,
          status: "outstanding",
          due_date: due,
          invoice_status: a.invoice_no.present? ? "issued" : "missing",
          receipt_status: a.receipt_no.present? ? "issued" : "missing",
          aging_bucket: bucket
        }
      end
      paid_list = attendees.select { |a| a.payment_status == "Paid" }.map do |a|
        {
          id: a.id,
          customer_name: a.name,
          amount: a.total_final_price,
          status: "paid",
          due_date: a.respond_to?(:due_date) ? a.due_date : nil,
          payment_date: a.respond_to?(:display_payment_date) ? a.display_payment_date : nil,
          invoice_status: a.invoice_no.present? ? "issued" : "missing",
          receipt_status: a.receipt_no.present? ? "issued" : "missing"
        }
      end
      @receivables_filter = params[:receivables_tab].presence || "all"
      @receivables = case @receivables_filter
        when "paid" then paid_list
        when "outstanding" then receivables_raw
        else receivables_raw + paid_list
      end
      @aging_0_7 = receivables_raw.count { |r| r[:aging_bucket] == :bucket_0_7 }
      @aging_8_30 = receivables_raw.count { |r| r[:aging_bucket] == :bucket_8_30 }
      @aging_30_plus = receivables_raw.count { |r| r[:aging_bucket] == :bucket_30_plus }
      @overdue_count = receivables_raw.count { |r| r[:due_date].present? && r[:due_date] < today }

      @expenses_filter = params[:expenses_status].presence || "all"
      @expenses_category = params[:expenses_category].presence
      expenses_scope = @class_expenses
      expenses_scope = expenses_scope.select { |e| e.payment_status == "paid" } if @expenses_filter == "paid"
      expenses_scope = expenses_scope.reject { |e| e.payment_status == "paid" } if @expenses_filter == "unpaid"
      expenses_scope = expenses_scope.select { |e| e.category == @expenses_category } if @expenses_category.present?
      @expenses_list = expenses_scope

      @finance_summary = {
        revenue: {
          expected: expected_revenue,
          paid: paid_revenue,
          outstanding: outstanding_revenue
        },
        costs: {
          instructor_fee: cost_instructor,
          venue: 0,
          food: 0,
          materials: 0,
          other: cost_other,
          total: total_costs,
          paid: paid_costs,
          unpaid: unpaid_costs
        },
        result: {
          profit: profit_paid,
          margin_pct: margin_paid
        },
        profit_paid_based: profit_paid,
        profit_expected_based: profit_expected,
        margin_paid_based: margin_paid,
        margin_expected_based: margin_expected,
        break_even_seats: break_even_seats,
        break_even_amount: break_even_amount,
        currency: "THB"
      }
    end
  end
end
