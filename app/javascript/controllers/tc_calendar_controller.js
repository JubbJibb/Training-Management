import { Controller } from "@hotwired/stimulus"

/**
 * Calendar grid: click on empty cell/slot opens Quick Add popover with prefilled date (and optional time).
 * Prevents opening when click is on an event link.
 * TODO: drag-drop (event move between days/slots); TODO: resize (event duration); stub for later.
 */
export default class extends Controller {
  static targets = ["cell", "slot", "grid"]

  onCellClick(event) {
    if (event.target.closest("a")) return
    const cell = event.target.closest("[data-tc-calendar-target='cell']")
    if (!cell) return
    const date = cell.dataset.date
    if (!date) return
    this.openQuickAdd({ date, time: null }, event)
  }

  onSlotClick(event) {
    if (event.target.closest("a")) return
    const slot = event.target.closest("[data-tc-calendar-target='slot']")
    if (!slot) return
    const date = slot.dataset.date
    const time = slot.dataset.time || null
    this.openQuickAdd({ date, time }, event)
  }

  onGridClick(event) {
    const slot = event.target.closest("[data-tc-calendar-target='slot']")
    const cell = event.target.closest("[data-tc-calendar-target='cell']")
    if (slot) this.onSlotClick(event)
    else if (cell) this.onCellClick(event)
  }

  openQuickAdd({ date, time }, clickEvent) {
    const anchor = document.getElementById("quick_add_anchor")
    const existing = document.getElementById("quick_add_form")
    if (existing) existing.remove()

    const params = new URLSearchParams(window.location.search)
    const url = new URL("/operations/training_calendar/quick_add_form", window.location.origin)
    url.searchParams.set("date", date)
    if (time) url.searchParams.set("time", time)
    url.searchParams.set("start_date", params.get("start_date") || new Date().toISOString().slice(0, 10))
    url.searchParams.set("view", params.get("view") || "week")

    fetch(url.toString(), {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    }).then(r => r.text()).then(html => {
      const wrap = document.createElement("div")
      wrap.innerHTML = html.trim()
      const form = wrap.querySelector(".tc-quick-add") || wrap.firstElementChild
      if (!form) return
      form.id = "quick_add_form"
      const root = document.getElementById("floating-ui-root") || document.body
      if (anchor) {
        anchor.style.position = "relative"
        anchor.hidden = false
        anchor.appendChild(form)
      } else {
        form.classList.add("tc-quick-add--fixed")
        root.appendChild(form)
      }
      const x = clickEvent?.clientX ?? 100
      const y = clickEvent?.clientY ?? 100
      form.style.position = "fixed"
      form.style.top = `${Math.min(y, window.innerHeight - 320)}px`
      form.style.left = `${Math.min(x, window.innerWidth - 320)}px`
      form.style.zIndex = "1000"
      form.querySelector("input[name='training_class[date]']")?.focus?.()
    }).catch(() => {
      const form = document.createElement("div")
      form.id = "quick_add_form"
      form.className = "tc-quick-add"
      form.innerHTML = `<p class="tc-quick-add__title">Quick add</p><a href="/admin/training_classes/new">Add new class</a>`
      ;(document.getElementById("floating-ui-root") || document.body).appendChild(form)
    })
  }
}
