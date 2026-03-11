import { Controller } from "@hotwired/stimulus"

const MONTH_WORKING_DAYS = { 1: 22, 2: 20, 3: 22, 4: 21, 5: 22, 6: 21, 7: 22, 8: 22, 9: 21, 10: 23, 11: 21, 12: 22 }

export default class extends Controller {
  static targets = [
    "month", "workingDays", "allocation", "includeVat",
    "totalDisplay", "rateLabel", "rateValue", "daysValue", "allocationValue",
    "subtotalValue", "vatRow", "vatValue"
  ]
  static values = { rate: { type: Number, default: 0 }, workingDays: { type: Number, default: 20 } }

  connect() {
    const rateInput = document.getElementById("budget_staff_profile_internal_day_rate") || document.querySelector("input[name='budget_staff_profile[internal_day_rate]']")
    if (rateInput) {
      rateInput.addEventListener("input", () => this.update())
      rateInput.addEventListener("change", () => this.update())
    }
    this.update()
  }

  update() {
    const rate = this.rateFromForm()
    const monthNum = this.hasMonthTarget ? parseInt(this.monthTarget.value, 10) : new Date().getMonth() + 1
    const defaultDays = MONTH_WORKING_DAYS[monthNum] || 20
    if (this.hasWorkingDaysTarget && this.workingDaysTarget.value === "") this.workingDaysTarget.value = defaultDays
    const days = this.hasWorkingDaysTarget ? parseFloat(this.workingDaysTarget.value) || 0 : defaultDays
    const pct = this.hasAllocationTarget ? parseFloat(this.allocationTarget.value) || 100 : 100
    const includeVat = this.hasIncludeVatTarget && this.includeVatTarget.checked
    const monthlyCost = (rate * days * (pct / 100))
    const vat = includeVat ? monthlyCost * 0.07 : 0
    const total = monthlyCost + vat

    const fmt = (n) => new Intl.NumberFormat("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)
    if (this.hasTotalDisplayTarget) this.totalDisplayTarget.textContent = `${fmt(total)} ฿/month`
    if (this.hasRateValueTarget) this.rateValueTarget.textContent = `${fmt(rate)} ฿/day`
    if (this.hasDaysValueTarget) this.daysValueTarget.textContent = days
    if (this.hasAllocationValueTarget) this.allocationValueTarget.textContent = pct
    if (this.hasSubtotalValueTarget) this.subtotalValueTarget.textContent = `${fmt(monthlyCost)} ฿`
    if (this.hasVatRowTarget) this.vatRowTarget.style.display = includeVat ? "" : "none"
    if (this.hasVatValueTarget) this.vatValueTarget.textContent = `${fmt(vat)} ฿`
  }

  rateFromForm() {
    const rateInput = document.getElementById("budget_staff_profile_internal_day_rate") || document.querySelector("input[name='budget_staff_profile[internal_day_rate]']")
    if (rateInput && rateInput.value !== "") return parseFloat(rateInput.value) || 0
    return this.rateValue
  }

  copySummary() {
    const rate = this.rateFromForm()
    const days = this.hasWorkingDaysTarget ? parseFloat(this.workingDaysTarget.value) || 0 : 0
    const pct = this.hasAllocationTarget ? parseFloat(this.allocationTarget.value) || 100 : 100
    const includeVat = this.hasIncludeVatTarget && this.includeVatTarget.checked
    const monthlyCost = (rate * days * (pct / 100))
    const vat = includeVat ? monthlyCost * 0.07 : 0
    const total = monthlyCost + vat
    const fmt = (n) => new Intl.NumberFormat("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)
    const text = `Rate: ${fmt(rate)} ฿/day | Working days: ${days} | Allocation: ${pct}% | Subtotal: ${fmt(monthlyCost)} ฿${includeVat ? ` | VAT 7%: ${fmt(vat)} ฿` : ""} | Total: ${fmt(total)} ฿/month`
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => this.showToast("Summary copied to clipboard"))
    } else {
      this.showToast(text)
    }
  }

  applyAsDefault() {
    this.showToast("Apply as default for worklog (placeholder)")
  }

  showToast(message) {
    const el = document.createElement("div")
    el.className = "alert alert-success alert-dismissible fade show position-fixed"
    el.style.cssText = "top: 1rem; right: 1rem; z-index: 9999; min-width: 200px;"
    el.setAttribute("role", "alert")
    el.innerHTML = `${message} <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>`
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 3000)
  }
}
