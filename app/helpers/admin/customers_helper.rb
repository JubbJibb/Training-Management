# frozen_string_literal: true

module Admin::CustomersHelper
  # Segment label for display (INDI → Individual, CORP → Corporate)
  def customer_360_segment_label(customer)
    case customer.participant_type.to_s
    when "Corp" then "CORP"
    when "Indi" then "INDI"
    else customer.participant_type.presence || "—"
    end
  end

  def attendee_only(attendees)
    Array(attendees).select { |a| a.status.to_s == "attendee" || a.status.blank? }
  end

  # Total spent (LTV): sum of total_final_price for paid attendees
  def customer_360_total_spent(attendees)
    attendee_only(attendees).select { |a| a.payment_status == "Paid" }.sum { |a| a.total_final_price.to_f }.round(2)
  end

  # Outstanding: sum of total_final_price for pending attendees
  def customer_360_outstanding(attendees)
    attendee_only(attendees).select { |a| a.payment_status == "Pending" }.sum { |a| a.total_final_price.to_f }.round(2)
  end

  # Last activity: max of customer.updated_at and attendee updated_at
  def customer_360_last_activity_at(customer, attendees)
    times = [customer.updated_at]
    attendees.each { |a| times << a.updated_at }
    times.compact.max
  end

  # Count of document status per type (QT, INV, Receipt) for attendees
  def customer_360_doc_counts(attendees)
    list = attendee_only(attendees)
    return {
      qt: list.count { |a| a.document_status == "QT" },
      inv: list.count { |a| a.document_status == "INV" },
      receipt: list.count { |a| a.document_status == "Receipt" },
      missing_qt: list.count { |a| a.document_status.blank? },
      missing_inv: list.count { |a| !%w[INV Receipt].include?(a.document_status.to_s) },
      missing_receipt: list.count { |a| a.document_status.to_s != "Receipt" }
    }
  end

  # Payment summary: paid count, pending count
  def customer_360_payment_summary(attendees)
    list = attendee_only(attendees)
    paid = list.count { |a| a.payment_status == "Paid" }
    pending = list.count { |a| a.payment_status == "Pending" }
    total = list.size
    collection_rate = total.positive? ? (paid.to_f / total * 100).round(1) : 0
    return { paid: paid, pending: pending, total: total, collection_rate: collection_rate }
  end

  # List of missing billing fields for the customer (for QT/INV/Receipt)
  def customer_360_missing_billing_fields(customer)
    missing = []
    missing << "Tax ID" if customer.tax_id.blank?
    missing << "Billing Name" if customer.billing_name.blank?
    missing << "Billing Address" if customer.billing_address.blank?
    missing
  end

  # Format currency consistently (฿ with comma, 2 decimals)
  def customer_360_thb(number)
    number_to_thb(number, decimals: 2)
  end

  # Customer "since" – first registration date if available
  def customer_360_first_registration_at(attendees)
    list = Array(attendees)
    return nil if list.empty?
    list.map(&:created_at).compact.min
  end
end
