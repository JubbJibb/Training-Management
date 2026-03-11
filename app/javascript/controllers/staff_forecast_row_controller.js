import { Controller } from "@hotwired/stimulus"

// Inline forecast row: recalc estimated cost on input, submit form on change.
export default class extends Controller {
  static targets = ["plannedDaysInput", "estimatedCost", "row"]

  recalc() {
    if (!this.hasPlannedDaysInputTarget || !this.hasEstimatedCostTarget) return
    const rate = parseFloat(this.rowTarget.dataset.rate || "0")
    const days = parseFloat(this.plannedDaysInputTarget.value || "0") || 0
    const cost = (days * rate).toFixed(2)
    this.estimatedCostTarget.textContent = formatThb(cost)
  }

  submitRow() {
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}

function formatThb(num) {
  const n = parseFloat(num)
  if (Number.isNaN(n)) return "—"
  return new Intl.NumberFormat("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n) + " ฿"
}
