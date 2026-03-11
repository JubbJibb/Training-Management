import { Controller } from "@hotwired/stimulus"

/**
 * Event / Day modals: close on ESC, close on backdrop click.
 * Close is done by fetching modal_close URL and replacing frame content.
 */
export default class extends Controller {
  static targets = ["backdrop", "dialog"]

  closeOnEscape(event) {
    if (event.key !== "Escape") return
    const frame = document.getElementById("tc_event_modal")
    const dayFrame = document.getElementById("tc_day_modal")
    if (frame && frame.querySelector(".tc-modal-backdrop")) {
      this.closeEventModal()
    }
    if (dayFrame && dayFrame.querySelector(".tc-modal-backdrop")) {
      this.closeDayModal()
    }
  }

  closeBackdrop(event) {
    if (event.target !== this.backdropTarget) return
    if (this.backdropTarget.closest("#tc_event_modal")) {
      this.closeEventModal()
    } else if (this.backdropTarget.closest("#tc_day_modal")) {
      this.closeDayModal()
    }
  }

  closeEventModal() {
    const frame = document.getElementById("tc_event_modal")
    if (!frame) return
    fetch("/operations/training_calendar/modal/close?which=event", { headers: { "Accept": "text/html" } })
      .then(r => r.text())
      .then(() => { frame.innerHTML = "" })
      .catch(() => { frame.innerHTML = "" })
  }

  closeDayModal() {
    const frame = document.getElementById("tc_day_modal")
    if (!frame) return
    fetch("/operations/training_calendar/modal/close?which=day", { headers: { "Accept": "text/html" } })
      .then(r => r.text())
      .then(() => { frame.innerHTML = "" })
      .catch(() => { frame.innerHTML = "" })
  }
}
