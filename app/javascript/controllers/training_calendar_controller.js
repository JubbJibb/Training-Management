import { Controller } from "@hotwired/stimulus"

/**
 * Training Calendar: filter drawer, filter chips, quick-add popover, ESC close.
 * Targets: filterDrawer, chips, quickAddPopover, quickAddAnchor.
 */
export default class extends Controller {
  static targets = ["filterDrawer", "chips", "quickAddPopover", "quickAddAnchor"]

  connect() {
    this.boundKeydown = this.closeOnEsc.bind(this)
    this.boundCloseQuickAdd = this.closeQuickAdd.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    window.addEventListener("tc:closeQuickAdd", this.boundCloseQuickAdd)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    window.removeEventListener("tc:closeQuickAdd", this.boundCloseQuickAdd)
  }

  openFilterDrawer() {
    if (!this.hasFilterDrawerTarget) return
    this.filterDrawerTarget.setAttribute("aria-hidden", "false")
    this.filterDrawerTarget.classList.add("is-open")
  }

  closeFilterDrawer() {
    if (!this.hasFilterDrawerTarget) return
    this.filterDrawerTarget.setAttribute("aria-hidden", "true")
    this.filterDrawerTarget.classList.remove("is-open")
  }

  removeChip(event) {
    const key = event.currentTarget.dataset.filterKey
    if (!key) return
    const params = new URLSearchParams(window.location.search)
    params.delete(key)
    const qs = params.toString()
    window.location.search = qs ? `?${qs}` : ""
  }

  closeQuickAdd() {
    const popover = document.getElementById("quick_add_form")
    if (popover) {
      popover.remove()
    }
    const trigger = document.getElementById("tc_close_quick_add_trigger")
    if (trigger) trigger.remove()
  }

  closeOnEsc(event) {
    if (event.key !== "Escape") return
    if (this.hasFilterDrawerTarget && this.filterDrawerTarget.classList.contains("is-open")) {
      this.closeFilterDrawer()
    }
    this.closeQuickAdd()
  }

  onQuickAddSubmit(event) {
    if (event.detail.success) {
      this.closeQuickAdd()
    }
  }

  openDayPopover() {
    // Day popover is loaded via Turbo Frame; no extra JS unless we want to position it
  }
}
