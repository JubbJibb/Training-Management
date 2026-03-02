import { Controller } from "@hotwired/stimulus"

// Opens the KPI detail modal and loads the detail content into the turbo frame by setting its src.
export default class extends Controller {
  static values = {
    url: String,
    frameId: { type: String, default: "kpi_detail_content" },
    modalId: { type: String, default: "financialsKpiDetailModal" }
  }

  open(event) {
    event.preventDefault()
    const url = this.urlValue || this.element.getAttribute("href")
    if (!url) return

    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      frame.src = url
    }

    const modalEl = document.getElementById(this.modalIdValue)
    if (modalEl && typeof bootstrap !== "undefined") {
      const modal = bootstrap.Modal.getOrCreateInstance(modalEl)
      modal.show()
    }
  }
}
