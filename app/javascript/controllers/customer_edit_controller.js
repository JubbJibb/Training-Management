import { Controller } from "@hotwired/stimulus"

// Toggles tips and hints by Type (Indi/Corp), optional Billing Name autofill, and live document preview.
export default class extends Controller {
  static targets = [
    "typeField",
    "typeSelect",
    "companyHintIndi",
    "companyHintCorp",
    "companyWarning",
    "tipsIndi",
    "tipsCorp",
    "companyInput",
    "previewBillingName",
    "previewAddress"
  ]

  connect() {
    this.onTypeChange()
    this.updatePreview()
  }

  onTypeChange() {
    const select = this.hasTypeSelectTarget ? this.typeSelectTarget : this.typeFieldTarget?.querySelector?.("select")
    const value = select?.value || "Indi"
    const isCorp = value === "Corp"

    this.toggleHint(isCorp)
    this.toggleTips(isCorp)
    this.toggleCompanyWarning(isCorp)
  }

  toggleHint(isCorp) {
    if (this.hasCompanyHintIndiTarget) this.companyHintIndiTarget.hidden = isCorp
    if (this.hasCompanyHintCorpTarget) this.companyHintCorpTarget.hidden = !isCorp
  }

  toggleTips(isCorp) {
    if (this.hasTipsIndiTarget) this.tipsIndiTarget.hidden = isCorp
    if (this.hasTipsCorpTarget) this.tipsCorpTarget.hidden = !isCorp
  }

  toggleCompanyWarning(isCorp) {
    if (!this.hasCompanyWarningTarget) return
    const companyEmpty = !this.companyInputTarget?.value?.trim()
    this.companyWarningTarget.hidden = !(isCorp && companyEmpty)
  }

  onPreviewInput() {
    this.updatePreview()
  }

  updatePreview() {
    const form = this.element.closest("form")
    if (!form) return
    const billingName = form.querySelector("[name='customer[billing_name]']")?.value?.trim()
    const billingAddress = form.querySelector("[name='customer[billing_address]']")?.value?.trim()
    if (this.hasPreviewBillingNameTarget) this.previewBillingNameTarget.textContent = billingName || "—"
    if (this.hasPreviewAddressTarget) this.previewAddressTarget.textContent = billingAddress || "—"
    this.toggleCompanyWarning(
      (form.querySelector("[name='customer[participant_type]']")?.value || "Indi") === "Corp"
    )
  }
}
