import { Controller } from "@hotwired/stimulus"

// Click-to-edit cell for attendee ledger: read surface by default; input/select on activate.
// number: blur/Enter save if changed; Esc cancels.
// select: change saves if different; blur without change closes read-only again.
export default class extends Controller {
  static targets = ["display", "editor", "control", "form"]
  static values = { inputMode: String }

  connect() {
    this._editing = false
    this._captureOriginal()
    this._onSubmitEnd = () => {
      this.element.classList.remove("ledger-cell--saving")
    }
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("turbo:submit-end", this._onSubmitEnd)
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("turbo:submit-end", this._onSubmitEnd)
    }
  }

  _captureOriginal() {
    if (this.hasControlTarget) this.originalValue = this.controlTarget.value
  }

  open(event) {
    if (event) event.preventDefault()
    if (this._editing || !this.hasControlTarget) return
    this._editing = true
    this.originalValue = this.controlTarget.value
    this.displayTarget.setAttribute("hidden", "")
    this.editorTarget.removeAttribute("hidden")
    this.element.classList.add("ledger-cell--editing")
    queueMicrotask(() => {
      this.controlTarget.focus()
      if (this.controlTarget.tagName === "INPUT" && typeof this.controlTarget.select === "function") {
        try {
          this.controlTarget.select()
        } catch (_) {
          /* readonly inputs */
        }
      }
    })
  }

  displayKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.open()
    }
  }

  onControlKeydown(event) {
    if (!this._editing) return
    if (event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
      this.cancel()
      return
    }
    if (this.inputModeValue === "number" && event.key === "Enter") {
      event.preventDefault()
      this.commitFromInput()
    }
  }

  onControlBlur() {
    if (!this._editing) return
    if (this.inputModeValue === "select") {
      setTimeout(() => this._closeSelectIfUnchanged(), 0)
      return
    }
    setTimeout(() => {
      if (!this._editing) return
      this.commitFromInput()
    }, 150)
  }

  onSelectChange() {
    if (!this._editing) return
    if (this.controlTarget.value !== this.originalValue) {
      this.submitForm()
    }
  }

  _closeSelectIfUnchanged() {
    if (!this._editing) return
    if (this.controlTarget.value === this.originalValue) {
      this._closeEditor()
    }
  }

  cancel() {
    if (!this._editing || !this.hasControlTarget) return
    this.controlTarget.value = this.originalValue
    this._closeEditor()
  }

  commitFromInput() {
    if (!this._editing) return
    if (this.controlTarget.value !== this.originalValue) {
      this.submitForm()
    } else {
      this._closeEditor()
    }
  }

  submitForm() {
    if (!this.hasFormTarget) return
    this.element.classList.add("ledger-cell--saving")
    this.formTarget.requestSubmit()
  }

  _closeEditor() {
    this._editing = false
    if (this.hasDisplayTarget) this.displayTarget.removeAttribute("hidden")
    if (this.hasEditorTarget) this.editorTarget.setAttribute("hidden", "")
    this.element.classList.remove("ledger-cell--editing")
  }
}
