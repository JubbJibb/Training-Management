import { Controller } from "@hotwired/stimulus"

// Submits the parent form on change (select/input). Optional debounce for text input.
export default class extends Controller {
  static values = {
    debounce: { type: Number, default: 0 }
  }

  connect() {
    this.debounceTimeout = null
  }

  submit() {
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }

  submitDebounced() {
    if (this.debounceValue > 0) {
      if (this.debounceTimeout) clearTimeout(this.debounceTimeout)
      this.debounceTimeout = setTimeout(() => this.submit(), this.debounceValue)
    } else {
      this.submit()
    }
  }
}
