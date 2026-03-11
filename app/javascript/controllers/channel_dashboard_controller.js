import { Controller } from "@hotwired/stimulus"

/**
 * Channel mix + Channel performance: active channel selection and sort.
 * - activeChannel: highlights matching breakdown row and table row; used for drilldown/filter.
 * - sortBy: "revenue" | "paid" for table order.
 * Targets: breakdownRow (data-channel-id), perfRow (data-channel-id), clearFilterBtn, sortBtn (data-sort).
 */
export default class extends Controller {
  static targets = ["breakdownRow", "perfRow", "clearFilterBtn", "sortBtn"]
  static values = {
    activeChannel: { type: String, default: "" },
    sortBy: { type: String, default: "revenue" }
  }

  connect() {
    this.syncHighlight()
    this.syncClearVisibility()
    this.syncSortButtons()
  }

  activeChannelValueChanged() {
    this.syncHighlight()
    this.syncClearVisibility()
  }

  sortByValueChanged() {
    this.syncSortButtons()
    this.sortTable()
  }

  /** Click breakdown row or donut segment: set active channel */
  selectChannel(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()
    const id = event.currentTarget?.dataset?.channelId ?? event.currentTarget?.closest?.("[data-channel-id]")?.dataset?.channelId
    if (id !== undefined) {
      this.activeChannelValue = id
    }
  }

  /** Clear active channel filter */
  clearChannel() {
    this.activeChannelValue = ""
  }

  /** Segmented control: change sort */
  changeSort(event) {
    const sort = event.currentTarget?.dataset?.sort
    if (sort === "revenue" || sort === "paid") {
      this.sortByValue = sort
    }
  }

  syncHighlight() {
    const ch = this.activeChannelValue
    this.breakdownRowTargets.forEach(row => {
      const id = row.dataset.channelId ?? ""
      row.classList.toggle("bi-channel-breakdown-row--active", id === ch && ch !== "")
    })
    this.perfRowTargets.forEach(row => {
      const id = row.dataset.channelId ?? ""
      row.classList.toggle("bi-channel-perf-row--active", id === ch && ch !== "")
    })
  }

  syncClearVisibility() {
    const hasActive = this.activeChannelValue !== ""
    this.clearFilterBtnTargets.forEach(btn => {
      btn.classList.toggle("bi-channel-clear--visible", hasActive)
      btn.hidden = !hasActive
    })
  }

  syncSortButtons() {
    const current = this.sortByValue
    this.sortBtnTargets.forEach(btn => {
      const sort = btn.dataset.sort ?? ""
      btn.classList.toggle("bi-sort-btn--active", sort === current)
      btn.setAttribute("aria-pressed", sort === current ? "true" : "false")
    })
  }

  sortTable() {
    const tbody = this.element.querySelector(".bi-channel-perf-table tbody")
    if (!tbody) return
    const sortKey = this.sortByValue
    const rows = Array.from(tbody.querySelectorAll("tr[data-channel-id]"))
    const getVal = row => {
      const v = row.dataset[sortKey]
      return sortKey === "revenue" ? parseFloat(v) || 0 : parseInt(v, 10) || 0
    }
    rows.sort((a, b) => getVal(b) - getVal(a))
    rows.forEach(r => tbody.appendChild(r))
  }
}
