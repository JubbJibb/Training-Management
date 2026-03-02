import { Controller } from "@hotwired/stimulus"

/**
 * Top-nav dropdown: open on click, close on outside click / ESC.
 * Optional: open on hover for desktop (data-nav-dropdown-optional-hover-value="true").
 * ARIA: trigger has aria-expanded + aria-controls; panel has role="menu"; links role="menuitem".
 */
export default class extends Controller {
  static targets = ["trigger", "panel", "item"]
  static values = {
    optionalHover: { type: Boolean, default: false }
  }

  connect() {
    this.boundClose = this.close.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("click", this.boundClose, true)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose, true)
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const open = this.triggerTarget.getAttribute("aria-expanded") !== "true"
    this.setOpen(open)
  }

  close(event) {
    if (event && event.type === "click") {
      if (this.element.contains(event.target)) return
    }
    this.setOpen(false)
  }

  setOpen(open) {
    const trigger = this.triggerTarget
    const panel = this.panelTarget
    trigger.setAttribute("aria-expanded", open)
    if (open) {
      panel.removeAttribute("hidden")
      this.element.classList.add("show")
    } else {
      panel.setAttribute("hidden", "")
      this.element.classList.remove("show")
    }
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return
    if (this.triggerTarget.getAttribute("aria-expanded") === "true") {
      this.setOpen(false)
      this.triggerTarget.focus()
    }
  }

  openOnHover() {
    if (!this.optionalHoverValue) return
    if (this.hoverCloseTimer) {
      clearTimeout(this.hoverCloseTimer)
      this.hoverCloseTimer = null
    }
    this.setOpen(true)
  }

  closeOnHover() {
    if (!this.optionalHoverValue) return
    this.hoverCloseTimer = setTimeout(() => {
      this.setOpen(false)
      this.hoverCloseTimer = null
    }, 150)
  }
}
