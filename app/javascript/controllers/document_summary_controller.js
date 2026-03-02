import { Controller } from "@hotwired/stimulus"

// Document Summary: handle action button clicks (create, view, none).
// Ready for future integration with document creation/viewing modals.
export default class extends Controller {
  static targets = ["row"]

  handleAction(event) {
    const button = event.currentTarget
    if (button.disabled) return
    const type = button.dataset.documentSummaryTypeParam
    const action = button.dataset.documentSummaryActionParam
    event.preventDefault()
    // Future: dispatch custom event or open modal
    this.dispatch("action", { detail: { type, action }, prefix: "document-summary" })
  }
}
