import { Controller } from "@hotwired/stimulus"

/**
 * When this element is connected (e.g. after Turbo Stream append), dispatch a custom event.
 * Used to signal "close quick add popover" after successful create.
 */
export default class extends Controller {
  static values = { event: { type: String, default: "tc:closeQuickAdd" } }

  connect() {
    window.dispatchEvent(new CustomEvent(this.eventValue))
    this.element.remove()
  }
}
