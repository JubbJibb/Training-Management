import { Controller } from "@hotwired/stimulus"

/**
 * Business Insights dashboard: channel selection, sort, and top-list view.
 * State: activeChannel, sortBy (revenue|paid), topListView (channel|course|top_spender|repeat).
 * Actions: selectChannel, clearChannel, changeSort, changeTopListView.
 */
export default class extends Controller {
  static targets = ["breakdownRow", "perfRow", "clearFilterBtn", "sortBtn", "topListBtn", "topListPane"]
  static values = {
    activeChannel: { type: String, default: "" },
    sortBy: { type: String, default: "revenue" },
    topListView: { type: String, default: "channel" }
  }

  connect() {
    this.syncHighlight()
    this.syncClearVisibility()
    this.syncSortButtons()
    this.syncTopListPanes()
  }

  activeChannelValueChanged() {
    this.syncHighlight()
    this.syncClearVisibility()
  }

  sortByValueChanged() {
    this.syncSortButtons()
    this.sortTable()
  }

  topListViewValueChanged() {
    this.syncTopListButtons()
    this.syncTopListPanes()
  }

  selectChannel(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()
    const id = event.currentTarget?.dataset?.channelId ?? event.currentTarget?.closest?.("[data-channel-id]")?.dataset?.channelId
    if (id !== undefined) this.activeChannelValue = id
  }

  clearChannel() {
    this.activeChannelValue = ""
  }

  changeSort(event) {
    const sort = event.currentTarget?.dataset?.sort
    if (sort === "revenue" || sort === "paid") this.sortByValue = sort
  }

  changeTopListView(event) {
    const view = event.currentTarget?.dataset?.value
    if (view) this.topListViewValue = view
  }

  syncHighlight() {
    const ch = this.activeChannelValue
    this.breakdownRowTargets.forEach(row => {
      const id = row.dataset.channelId ?? ""
      row.classList.toggle("insight-data-table__row--active", id === ch && ch !== "")
    })
    this.perfRowTargets.forEach(row => {
      const id = row.dataset.channelId ?? ""
      row.classList.toggle("insight-data-table__row--active", id === ch && ch !== "")
    })
  }

  syncClearVisibility() {
    const hasActive = this.activeChannelValue !== ""
    this.clearFilterBtnTargets.forEach(btn => {
      btn.classList.toggle("insight-card__clear--visible", hasActive)
      btn.hidden = !hasActive
    })
  }

  syncSortButtons() {
    const current = this.sortByValue
    this.sortBtnTargets.forEach(btn => {
      const sort = btn.dataset.sort ?? ""
      btn.classList.toggle("segmented-control__btn--active", sort === current)
      btn.setAttribute("aria-pressed", sort === current ? "true" : "false")
    })
  }

  syncTopListButtons() {
    const current = this.topListViewValue
    this.topListBtnTargets.forEach(btn => {
      const val = btn.dataset.value ?? ""
      btn.classList.toggle("segmented-control__btn--active", val === current)
      btn.setAttribute("aria-pressed", val === current ? "true" : "false")
    })
  }

  syncTopListPanes() {
    const current = this.topListViewValue
    this.topListPaneTargets.forEach(pane => {
      const paneView = pane.dataset.pane ?? ""
      pane.hidden = paneView !== current
    })
  }

  sortTable() {
    const tbody = this.element.querySelector(".insight-data-table tbody")
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
