import { Controller } from "@hotwired/stimulus"

// Handles "Send Email" with selectable customers: select-all checkbox and opening mailto with BCC of selected emails.
// Uses querySelector within element so it works after Turbo Frame replaces the table.
export default class extends Controller {
  static targets = ["selectAll", "rowCheckbox"]
  static values = {}

  connect() {}

  toggleAll() {
    const selectAll = this.element.querySelector('[data-customer-email-select-target="selectAll"]')
    if (!selectAll) return
    const checked = selectAll.checked
    this.element.querySelectorAll('[data-customer-email-select-target="rowCheckbox"]').forEach((el) => {
      if (el.dataset.email) el.checked = checked
    })
  }

  sendEmail(event) {
    event.preventDefault()
    const boxes = this.element.querySelectorAll('[data-customer-email-select-target="rowCheckbox"]')
    const emails = Array.from(boxes)
      .filter((el) => el.checked && el.dataset.email)
      .map((el) => el.dataset.email.trim())
      .filter(Boolean)
    if (emails.length === 0) {
      alert("กรุณาเลือกอย่างน้อย 1 รายการ (ลูกค้าที่มีอีเมล)")
      return
    }
    const bcc = emails.join(";")
    const url = `mailto:?bcc=${encodeURIComponent(bcc)}`
    window.open(url, "_blank", "noopener")
  }
}
