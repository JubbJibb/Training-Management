import { Controller } from "@hotwired/stimulus"

// Submits the form when month (or year) selector changes, to refresh the monthly summary Turbo frame.
export default class extends Controller {
  submit() {
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
