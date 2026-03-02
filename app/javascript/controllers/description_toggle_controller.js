import { Controller } from "@hotwired/stimulus"

// Toggles description block expand/collapse; switches button text "Expand" / "Collapse".
export default class extends Controller {
  static targets = ["button"]
  static values = {
    expanded: { type: Boolean, default: false }
  }

  connect() {
    this.updateButtonText()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.element.classList.toggle("is-expanded", this.expandedValue)
    this.updateButtonText()
  }

  updateButtonText() {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.expandedValue ? "Collapse" : "Expand"
      this.buttonTarget.setAttribute("aria-expanded", this.expandedValue)
    }
  }
}
