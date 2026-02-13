# frozen_string_literal: true

# Returns document-type counts for a training class (from attendees' document_status).
# Used by the Document Summary component. No separate Quotation/Invoice/Receipt models;
# counts are derived from Attendee scopes per class.
class DocumentSummaryService
  def initialize(class_id)
    @class_id = class_id
  end

  def summary
    {
      quotations: row(:quotations, "📄", "QT (Quotations)", qt_count, "create", "Create"),
      invoices: row(:invoices, "📋", "INV (Invoices)", inv_count, "create", "Create"),
      receipts: row(:receipts, "✅", "Receipt (ใบเสร็จ)", receipt_count, "view", "View"),
      other_documents: row(:other_documents, "📎", "Other Documents", other_count, "none", "—")
    }
  end

  private

  def row(type, icon, label, count, action, action_label)
    {
      type: type.to_s,
      icon: icon,
      label: label,
      count: count,
      action: action,
      action_label: action_label
    }
  end

  def base_scope
    Attendee.where(training_class_id: @class_id)
  end

  def qt_count
    base_scope.where(document_status: "QT").count
  end

  def inv_count
    base_scope.where(document_status: "INV").count
  end

  def receipt_count
    base_scope.where(document_status: "Receipt").count
  end

  def other_count
    base_scope.where(document_status: [nil, ""]).count
  end
end
