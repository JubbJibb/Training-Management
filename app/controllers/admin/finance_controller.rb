module Admin
  class FinanceController < ApplicationController
    layout "admin"
    
    def index
      # KPI
      @revenue_this_month = calculate_revenue_this_month
      @paid_this_month = calculate_paid_this_month
      @outstanding_invoice = calculate_outstanding_invoice
      @overdue_payments = calculate_overdue_payments
      
      # Invoice Summary
      @inv_issued_this_month = Attendee.where(document_status: "INV")
                                       .where("created_at >= ?", Date.today.beginning_of_month)
                                       .count
      @inv_unpaid = Attendee.where(document_status: "INV", payment_status: "Pending").count
      @inv_overdue = Attendee.where(document_status: "INV", payment_status: "Pending")
                             .where("due_date < ?", Date.today)
                             .count
      @receipt_not_issued = Attendee.where(payment_status: "Paid")
                                    .where.not(document_status: "Receipt")
                                    .count
      
      # Revenue Breakdown
      @revenue_by_course = calculate_revenue_by_course
      @revenue_by_type = calculate_revenue_by_type
      @vat_summary = calculate_vat_summary
      
      # Payment Status List
      @payment_status_list = Attendee.joins(:training_class)
                                     .where(document_status: "INV")
                                     .order(:due_date)
                                     .includes(:training_class)
      
      # Corporate Billing Overview
      @corporate_billing = calculate_corporate_billing
    end
    
    private
    
    def calculate_revenue_this_month
      Attendee.joins(:training_class)
              .where("training_classes.date >= ? AND training_classes.date <= ?", 
                     Date.today.beginning_of_month, Date.today.end_of_month)
              .sum(:price)
    end
    
    def calculate_paid_this_month
      Attendee.joins(:training_class)
              .where(payment_status: "Paid")
              .where("training_classes.date >= ? AND training_classes.date <= ?", 
                     Date.today.beginning_of_month, Date.today.end_of_month)
              .sum(:price)
    end
    
    def calculate_outstanding_invoice
      Attendee.where(document_status: "INV", payment_status: "Pending").sum(:price)
    end
    
    def calculate_overdue_payments
      Attendee.where(document_status: "INV", payment_status: "Pending")
              .where("due_date < ?", Date.today)
              .sum(:price)
    end
    
    def calculate_revenue_by_course
      Attendee.joins(:training_class)
              .group("training_classes.title")
              .sum(:price)
    end
    
    def calculate_revenue_by_type
      {
        "Corp" => Attendee.where(participant_type: "Corp").sum(:price),
        "Indi" => Attendee.where(participant_type: "Indi").sum(:price)
      }
    end
    
    def calculate_vat_summary
      total_revenue = Attendee.sum(:price)
      vat_amount = total_revenue * 0.07
      {
        subtotal: total_revenue,
        vat: vat_amount,
        total: total_revenue + vat_amount
      }
    end
    
    def calculate_corporate_billing
      Attendee.where(participant_type: "Corp")
              .group(:company)
              .sum(:price)
              .map { |company, amount| { company: company || "Unknown", amount: amount } }
              .sort_by { |item| -item[:amount] }
    end
  end
end
