# frozen_string_literal: true

module Insights
  # Execution: Critical / Warning / Follow-up sections + task queue.
  # Overdue invoices, missing receipts, pending QT, low-enrollment classes, expiring promos, leads waiting.
  class ActionCenter
    CACHE_TTL = 2.minutes
    LOW_ENROLLMENT_FILL = 0.30
    DAYS_PROMO_EXPIRING = 14
    DAYS_CLASS_SOON = 14

    def initialize(params = {})
      @params = params
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          critical: critical_items,
          warning: warning_items,
          follow_up: follow_up_items,
          task_queue: task_queue
        }
      end
    end

    private

    def cache_key
      ["insights/action_center", Date.current.to_s].join("/")
    end

    def critical_items
      items = []
      overdue = Attendee.attendees.where(payment_status: "Pending").where("due_date IS NOT NULL AND due_date < ?", Date.current).count
      items << { label: "Overdue invoices", count: overdue, path: "finance_ar", cta: "View AR" } if overdue.positive?
      items
    end

    def warning_items
      items = []
      missing_receipt = Attendee.attendees.where(payment_status: "Paid").where.not(document_status: "Receipt").or(Attendee.attendees.where(payment_status: "Paid", document_status: nil)).count
      pending_qt = Attendee.attendees.where(payment_status: "Pending").where(document_status: [nil, ""]).count
      items << { label: "Missing receipts", count: missing_receipt, path: "finance_ar", cta: "View" } if missing_receipt.positive?
      items << { label: "Pending quotations", count: pending_qt, path: "finance_ar", cta: "View" } if pending_qt.positive?

      low_enrollment = TrainingClass.where("date >= ? AND date <= ?", Date.current, DAYS_CLASS_SOON.days.from_now.to_date)
        .where("max_attendees > 0")
        .select { |tc| (tc.fill_rate_percent || 0) < (LOW_ENROLLMENT_FILL * 100) }
      low_enrollment.each do |tc|
        items << { label: "Low enrollment: #{tc.title}", count: 1, path: "training_class", training_class_id: tc.id, cta: "View class" }
      end

      # Promotions "expiring" – we don't have end_date on Promotion; use active count or skip
      # If we had expires_at we'd filter. Placeholder: show active promos count as info only, or skip.
      items
    end

    def follow_up_items
      items = []
      leads = Attendee.where(status: "potential").where("created_at <= ?", 3.days.ago).count
      items << { label: "Leads waiting contact", count: leads, path: "admin_dashboard", cta: "Dashboard" } if leads.positive?
      items
    end

    def task_queue
      rows = []
      Attendee.attendees.includes(:training_class, :customer)
        .where(payment_status: "Pending")
        .where("due_date IS NOT NULL AND due_date < ?", Date.current)
        .order(:due_date)
        .limit(20)
        .each do |a|
        rows << {
          priority: "High",
          type: "Overdue invoice",
          client_or_class: a.customer&.company_name.presence || a.name,
          due_date: a.due_date,
          suggested_action: "Collect payment",
          training_class_id: a.training_class_id,
          attendee_id: a.id
        }
      end
      Attendee.attendees.where(payment_status: "Paid").where.not(document_status: "Receipt").or(Attendee.attendees.where(payment_status: "Paid", document_status: nil))
        .includes(:training_class, :customer).limit(10).each do |a|
        rows << {
          priority: "Medium",
          type: "Missing receipt",
          client_or_class: a.customer&.company_name.presence || a.name,
          due_date: nil,
          suggested_action: "Issue receipt",
          training_class_id: a.training_class_id,
          attendee_id: a.id
        }
      end
      Attendee.where(status: "potential").where("created_at <= ?", 5.days.ago).includes(:training_class, :customer).limit(5).each do |a|
        rows << {
          priority: "Medium",
          type: "Lead follow-up",
          client_or_class: a.name,
          due_date: a.created_at.to_date,
          suggested_action: "Contact lead",
          training_class_id: a.training_class_id,
          attendee_id: a.id
        }
      end
      rows.first(30)
    end
  end
end
