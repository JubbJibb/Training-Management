import { Controller } from "@hotwired/stimulus"

// Class workspace edit: `training_class[price]` is stored ex-VAT when VAT applies. Inc-VAT field is UI-only and syncs into the hidden price field.
export default class extends Controller {
  static targets = [
    "priceSubmit",
    "vatableBlock",
    "excludedBlock",
    "vatBreakdown",
    "excludedBreakdown",
    "incField",
    "excludedField",
    "exDisplay",
    "vatDisplay",
    "incDisplay",
    "exOnlyDisplay",
    "vatCheckbox"
  ]

  connect() {
    if (this.hasVatCheckboxTarget) {
      this.vatCheckboxTarget.addEventListener("change", () => {
        this.applyVisibility()
        this.syncValuesAfterToggle()
      })
    }
    this.applyVisibility()
    const ex = this.exFromSubmit()
    if (this.hasExcludedFieldTarget) this.excludedFieldTarget.value = this.round(ex, 2)
    if (this.hasIncFieldTarget) this.incFieldTarget.value = this.round(ex * 1.07, 2)
    if (this.vatExcluded()) this.syncExcludedToSubmit()
    else this.syncIncToSubmit()
    this.updateBreakdown()
  }

  applyVisibility() {
    const excluded = this.vatExcluded()
    if (this.hasVatableBlockTarget) this.vatableBlockTarget.classList.toggle("d-none", excluded)
    if (this.hasExcludedBlockTarget) this.excludedBlockTarget.classList.toggle("d-none", !excluded)
    if (this.hasVatBreakdownTarget) this.vatBreakdownTarget.classList.toggle("d-none", excluded)
    if (this.hasExcludedBreakdownTarget) this.excludedBreakdownTarget.classList.toggle("d-none", !excluded)
  }

  syncValuesAfterToggle() {
    const ex = this.exFromSubmit()
    if (this.vatExcluded()) {
      if (this.hasExcludedFieldTarget) this.excludedFieldTarget.value = this.round(ex, 2)
      this.syncExcludedToSubmit()
    } else {
      if (this.hasIncFieldTarget) this.incFieldTarget.value = this.round(ex * 1.07, 2)
      this.syncIncToSubmit()
    }
    this.updateBreakdown()
  }

  incChanged() {
    const inc = parseFloat(this.incFieldTarget.value) || 0
    const ex = this.round(inc / 1.07, 2)
    this.priceSubmitTarget.value = ex
    this.updateBreakdown()
  }

  excludedChanged() {
    this.syncExcludedToSubmit()
    this.updateBreakdown()
  }

  syncIncToSubmit() {
    if (!this.hasIncFieldTarget || !this.hasPriceSubmitTarget) return
    const inc = parseFloat(this.incFieldTarget.value) || 0
    this.priceSubmitTarget.value = this.round(inc / 1.07, 2)
    this.updateBreakdown()
  }

  syncExcludedToSubmit() {
    if (!this.hasExcludedFieldTarget || !this.hasPriceSubmitTarget) return
    const ex = parseFloat(this.excludedFieldTarget.value) || 0
    this.priceSubmitTarget.value = this.round(ex, 2)
    this.updateBreakdown()
  }

  exFromSubmit() {
    if (!this.hasPriceSubmitTarget) return 0
    return parseFloat(this.priceSubmitTarget.value) || 0
  }

  updateBreakdown() {
    const ex = this.exFromSubmit()
    if (this.vatExcluded()) {
      if (this.hasExOnlyDisplayTarget) this.exOnlyDisplayTarget.textContent = this.fmt(ex)
      return
    }
    const vat = this.round(ex * 0.07, 2)
    const inc = this.round(ex * 1.07, 2)
    if (this.hasExDisplayTarget) this.exDisplayTarget.textContent = this.fmt(ex)
    if (this.hasVatDisplayTarget) this.vatDisplayTarget.textContent = this.fmt(vat)
    if (this.hasIncDisplayTarget) this.incDisplayTarget.textContent = this.fmt(inc)
  }

  fmt(n) {
    return new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)
  }

  round(n, d) {
    const p = 10 ** d
    return Math.round((n + Number.EPSILON) * p) / p
  }

  vatExcluded() {
    return this.hasVatCheckboxTarget && this.vatCheckboxTarget.checked
  }
}
