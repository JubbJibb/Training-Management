import { Controller } from "@hotwired/stimulus"

// Submits the form when year selector changes (e.g. Budget Overview).
export default class extends Controller {
  submit() {
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
