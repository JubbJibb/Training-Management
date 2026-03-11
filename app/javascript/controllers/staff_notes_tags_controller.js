import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notes"]

  append(e) {
    const tag = e.currentTarget.dataset.notesTag
    if (!tag) return
    const ta = this.hasNotesTarget ? this.notesTarget : document.getElementById("staff_internal_notes")
    if (ta) {
      const prefix = ta.value.trim() ? ta.value.trim() + " " : ""
      ta.value = prefix + tag
      ta.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }
}
