# frozen_string_literal: true

module Admin
  class DataController < ApplicationController
    layout "admin"

    def index
      # Landing page for Data (Download / Upload) – optional; nav can link directly to downloads + upload form
    end

    def financial_report
      redirect_to admin_finance_index_path(format: :csv), allow_other_host: false
    end

    def customer_info
      require "csv"
      csv = CSV.generate(headers: true) do |rows|
        rows << %w[email name phone company tax_id billing_name billing_address]
        Customer.order(:email).find_each do |c|
          rows << [
            c.email,
            c.name,
            c.phone.to_s,
            c.company.to_s,
            c.tax_id.to_s,
            c.billing_name.to_s,
            (c.billing_address.to_s.gsub("\n", " ") rescue c.billing_address.to_s)
          ]
        end
      end
      send_data csv, filename: "customers-#{Date.current}.csv", type: "text/csv"
    end

    def attendee_list
      require "csv"
      csv = CSV.generate(headers: true) do |rows|
        rows << %w[class_date class_title name email phone company participant_type seats source_channel payment_status document_status]
        Attendee.attendees
          .joins(:training_class)
          .includes(:training_class)
          .order("training_classes.date DESC, attendees.name")
          .find_each do |a|
          rows << [
            a.training_class.date&.strftime("%Y-%m-%d"),
            a.training_class.title.to_s,
            a.name,
            a.email,
            a.phone.to_s,
            a.company.to_s,
            a.participant_type.to_s,
            a.seats.to_i,
            a.source_channel.to_s,
            a.payment_status.to_s,
            a.document_status.to_s
          ]
        end
      end
      send_data csv, filename: "attendee-list-#{Date.current}.csv", type: "text/csv"
    end

    def upload
      # GET: show upload form
    end

    def upload_customers
      file = params[:file]
      unless file&.respond_to?(:tempfile)
        redirect_to admin_data_upload_path, alert: "Please choose a CSV file."
        return
      end

      result = { updated: 0, errors: [], skipped: 0 }
      require "csv"
      CSV.foreach(file.tempfile, headers: true, encoding: "BOM|UTF-8").with_index(2) do |row, line_num|
        email = row["email"]&.strip&.downcase
        next (result[:skipped] += 1) if email.blank?

        customer = Customer.find_by(email: email)
        unless customer
          result[:errors] << "Line #{line_num}: No customer with email #{email}"
          next
        end

        customer.name = row["name"].to_s.strip.presence || customer.name
        customer.phone = row["phone"].to_s.strip.presence || customer.phone
        customer.company = row["company"].to_s.strip.presence || customer.company
        customer.tax_id = row["tax_id"].to_s.strip.presence || customer.tax_id
        customer.billing_name = row["billing_name"].to_s.strip.presence || customer.billing_name
        customer.billing_address = row["billing_address"].to_s.strip.presence || customer.billing_address

        if customer.save
          result[:updated] += 1
        else
          result[:errors] << "Line #{line_num}: #{customer.errors.full_messages.join(', ')}"
        end
      end

      flash[:notice] = "Updated #{result[:updated]} customer(s). Skipped #{result[:skipped]} row(s)."
      flash[:upload_errors] = result[:errors] if result[:errors].any?
      redirect_to admin_data_upload_path
    end
  end
end
