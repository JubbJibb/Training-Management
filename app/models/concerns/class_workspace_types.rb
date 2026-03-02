# frozen_string_literal: true

# Data shapes for Class Management Workspace (for API / frontend consistency).
# Replace with real API types when integrating.
#
# Class (TrainingClass)
#   id, title, date, end_date, start_time, end_time, location, max_attendees,
#   instructor, price, cost, description, duration, total_registered_seats,
#   net_revenue, checklist_items, notes
#
# Attendee
#   id, name, email, company, participant_type, seats, payment_status,
#   attendance_status, total_final_price, notes, document_status
#
# Lead (Attendee with status: potential)
#   id, name, email, company, notes, created_at, stage (interested|contacted|deciding|confirmed|lost)
#
# Document (generated or uploaded)
#   type (quotation|invoice|receipt|certificate_list|po|withholding_tax|transfer_slip),
#   label, count, action, action_label, url (for download)
#
# FinanceSummary
#   revenue: { expected, paid, outstanding }
#   costs: { instructor_fee, venue, food, materials, other, total }
#   result: { profit, margin_pct }
#   currency: "THB"
#
module ClassWorkspaceTypes
  # Data shapes documented above; API client can be added here when needed.
end
