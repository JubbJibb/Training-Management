import { Controller } from "@hotwired/stimulus"

/**
 * Right-side drawer: tab switching, unsaved changes warning, close.
 * Targets: tab, panel. Values: unsaved (Boolean).
 */
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { unsaved: { type: Boolean, default: false } }

  connect() {
    this.boundBeforeUnload = this.beforeUnload.bind(this)
    window.addEventListener("beforeunload", this.boundBeforeUnload)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
  }

  switchTab(event) {
    const tab = event.currentTarget
    const tabId = tab.dataset.tab
    if (!tabId) return
    this.tabTargets.forEach(t => {
      const isActive = t.dataset.tab === tabId
      t.classList.toggle("is-active", isActive)
      t.setAttribute("aria-selected", isActive)
    })
    this.panelTargets.forEach(p => {
      const panelId = p.id
      const show = (panelId === "tc_drawer_details" && tabId === "details") ||
        (panelId === "tc_drawer_registrants" && tabId === "registrants") ||
        (panelId === "tc_drawer_checklist" && tabId === "checklist")
      p.classList.toggle("is-active", show)
      p.hidden = !show
    })
  }

  markUnsaved() {
    this.unsavedValue = true
  }

  clearUnsaved() {
    this.unsavedValue = false
  }

  beforeUnload(event) {
    if (this.unsavedValue) {
      event.preventDefault()
    }
  }

  close() {
    if (this.unsavedValue && !window.confirm("You have unsaved changes. Leave?")) {
      return
    }
    window.location.href = this.element.dataset.drawerCloseUrl || document.querySelector("[data-tc-drawer-empty]")?.href || "#"
  }
}
