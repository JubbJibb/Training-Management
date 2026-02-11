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
      @inv_issued_this_month = Attendee.attendees.where(document_status: "INV")
                                       .where("created_at >= ?", Date.today.beginning_of_month)
                                       .count
      @inv_unpaid = Attendee.attendees.where(document_status: "INV", payment_status: "Pending").count
      @inv_overdue = Attendee.attendees.where(document_status: "INV", payment_status: "Pending")
                             .where("due_date < ?", Date.today)
                             .count
      @receipt_not_issued = Attendee.attendees.where(payment_status: "Paid")
                                    .where.not(document_status: "Receipt")
                                    .count
      
      # Revenue Breakdown
      @revenue_by_course = calculate_revenue_by_course
      @revenue_by_type = calculate_revenue_by_type
      @vat_summary = calculate_vat_summary
      
      # Payment Status List
      @payment_status_list = Attendee.attendees.joins(:training_class)
                                     .where(document_status: "INV")
                                     .order(:due_date)
                                     .includes(:training_class, :customer)
      
      # Corporate Billing Overview
      @corporate_billing = calculate_corporate_billing
    end
    
    private
    
    def calculate_revenue_this_month
      # Revenue นับตามวันที่ลงทะเบียน (created_at) ในเดือนนี้
      Attendee.attendees
              .where("created_at >= ? AND created_at <= ?", 
                     Date.today.beginning_of_month.beginning_of_day, 
                     Date.today.end_of_month.end_of_day)
              .sum { |a| a.calculate_final_price }
    end
    
    def calculate_paid_this_month
      # Paid revenue นับตามวันที่อัปเดต payment_status เป็น Paid ในเดือนนี้
      # หรือใช้ updated_at ถ้าไม่มี payment_date field
      Attendee.attendees
              .where(payment_status: "Paid")
              .where("updated_at >= ? AND updated_at <= ?", 
                     Date.today.beginning_of_month.beginning_of_day, 
                     Date.today.end_of_month.end_of_day)
              .sum { |a| a.calculate_final_price }
    end
    
    def calculate_outstanding_invoice
      Attendee.attendees.where(document_status: "INV", payment_status: "Pending").sum { |a| a.calculate_final_price }
    end
    
    def calculate_overdue_payments
      Attendee.attendees.where(document_status: "INV", payment_status: "Pending")
              .where("due_date < ?", Date.today)
              .sum { |a| a.calculate_final_price }
    end
    
    def calculate_revenue_by_course
      result = {}
      Attendee.attendees.joins(:training_class).includes(:training_class).each do |attendee|
        course_title = attendee.training_class.title
        result[course_title] ||= 0
        result[course_title] += attendee.calculate_final_price
      end
      result
    end
    
    def calculate_revenue_by_type
      {
        "Corp" => Attendee.attendees.where(participant_type: "Corp").sum { |a| a.calculate_final_price },
        "Indi" => Attendee.attendees.where(participant_type: "Indi").sum { |a| a.calculate_final_price }
      }
    end
    
    def calculate_vat_summary
      total_revenue = Attendee.attendees.sum { |a| a.calculate_final_price }
      total_revenue_before_vat = Attendee.attendees.sum { |a| a.calculate_price_before_vat }
      total_vat_amount = Attendee.attendees.sum { |a| a.calculate_vat_amount }
      {
        subtotal: total_revenue_before_vat,
        vat: total_vat_amount,
        total: total_revenue
      }
    end
    
    def calculate_corporate_billing
      result = {}
      Attendee.attendees.where(participant_type: "Corp").includes(:customer).find_each do |attendee|
        customer = attendee.customer
        company_key = customer&.company_name || attendee.company || "Unknown"
        result[company_key] ||= {
          company: company_key,
          amount: 0.0,
          paid_amount: 0.0,
          pending_amount: 0.0,
          customer: customer
        }

        final_price = attendee.calculate_final_price.to_f
        result[company_key][:amount] += final_price
        if attendee.payment_status == "Paid"
          result[company_key][:paid_amount] += final_price
        else
          result[company_key][:pending_amount] += final_price
        end
      end
      result.values.sort_by { |item| -item[:amount].to_f }
    end
  end
end
