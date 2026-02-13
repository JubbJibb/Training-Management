import { Controller } from "@hotwired/stimulus"

// Document Summary: handle action button clicks (create, view, none).
// Ready for future integration with document creation/viewing modals.
export default class extends Controller {
  static targets = ["row"]

  connect() {
    // Optional: smooth transitions on row hover are handled by CSS
  }

  handleAction(event) {
    const button = event.currentTarget
    if (button.disabled) return
    const type = button.dataset.documentSummaryTypeParam
    const action = button.dataset.documentSummaryActionParam
    // Log for now; will integrate with modals later
    if (typeof console !== "undefined" && console.log) {
      console.log("[DocumentSummary] action:", action, "type:", type)
    }
    event.preventDefault()
    // Future: dispatch custom event or open modal
    this.dispatch("action", { detail: { type, action }, prefix: "document-summary" })
  }
}
