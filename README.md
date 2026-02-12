# Training Management System

## Project Overview

ระบบจัดการการอบรมสำหรับคลาสสาธารณะ (Public Training Classes) พัฒนาด้วย **Ruby on Rails** เพื่อทดแทนการจัดการด้วย Excel ด้วยเว็บอินเทอร์เฟซที่ทันสมัย ครอบคลุมการจัดการคลาส การลงทะเบียน ลูกค้า การเงิน โปรโมชั่น และการส่งออกรายงาน (PDF/Excel) พร้อมระบบ Export แบบ background job และ Design System แบบรวมศูนย์

---

## Features

### Core
- **Training Class Management** — สร้าง แก้ไข ลบคลาส (วันที่ สถานที่ ราคา ต้นทุน ผู้สอน)
- **Attendee Management** — จัดการผู้เข้าร่วม (เพิ่ม/แก้ไข/ลบ), สถานะ Attendee / Potential, ย้ายระหว่างสองสถานะ
- **Customer Management** — รายชื่อลูกค้า ค้นหา แก้ไข; **Customer 360°** ดูประวัติลงทะเบียน เอกสาร การชำระเงิน ไทม์ไลน์; Sync ข้อมูล billing จาก registration ล่าสุด
- **Leads / Potential** — แยก Prospects จากผู้ลงทะเบียนจริง
- **Promotion & Discount** — Percentage, Fixed Amount, Buy X Get Y; ใช้ได้หลายโปรโมชั่นต่อคน
- **Payment & Documents** — สถานะ QT/INV/Receipt, อัปโหลดสลิป (PNG, JPG, GIF, PDF), Invoice No. / Due Date
- **Class Expenses** — บันทึกค่าใช้จ่ายต่อคลาส (หมวดหมู่, จำนวนเงิน)
- **VAT & Pricing** — ราคาก่อน VAT, VAT 7%, ราคารวม; Price per Head สำหรับ Corporate
- **Email** — ส่งอีเมลแจ้งเตือนให้ผู้เข้าร่วม (รายคน / ทั้งคลาส)
- **CSV** — ส่งออกรายชื่อผู้เข้าร่วม; นำเข้าข้อมูลจาก CSV (attendees, payments, quotations)
- **Export System** — PDF (Financial Report, Class Report, Customer Summary), Excel (Financial Data, Class Attendees, Customer Master, Customer for Accounting); background jobs, audit (requested_by), optional custom fields

### Dashboards & Pages
- **Admin Dashboard** — KPIs (Upcoming Classes, Attendees, New Leads, Repeat Learners, Pending QT, Unpaid Inv, Missing Receipts, Almost Full), Action Required, Upcoming Classes, Leads by Channel, Repeat/Top Customers
- **Finance Dashboard (admin)** — Revenue, Paid, Outstanding, Overdue; Invoice summary, Revenue breakdown, Payment list
- **CFO Finance Dashboard** — Turbo-driven filters, Cash flow, AR aging, Corporate ledger, Documents compliance
- **Training Classes Index** — รายการคลาส, KPI strip, filter, ตาราง
- **Class Detail** — Tabs: Attendees, Potential, Documents, Finance (รวม Class Expenses)
- **Customer Show (360°)** — Sticky header, Billing/Tax, Snapshot, Class history, Documents/Payments, Activity timeline, Export dropdown
- **Customer Edit** — Basic info + Billing/Tax, Side panel (tips, document preview), Sync from latest registration
- **Settings** — Promotions (CRUD), Promotion drilldown/export; Performance (Promo KPIs, Revenue share, Leaderboard)

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Ruby on Rails 8.1.x |
| **Ruby** | 3.x |
| **Database** | SQLite3 |
| **Server** | Puma |
| **Assets** | Propshaft, CSS Bundling (plain CSS) |
| **Frontend** | Turbo (Turbo Frames, Turbo Streams), Stimulus, Importmap (ESM) |
| **Auth** | Session-based admin (e.g. `session[:admin_user_id]`); bcrypt for password digest |
| **Authorization** | Pundit (e.g. `ExportJobPolicy`) |
| **Background Jobs** | Active Job + Solid Queue |
| **File Storage** | Active Storage (local); image_processing for variants |
| **Export** | Prawn + prawn-table (PDF), caxlsx + caxlsx_rails (Excel) |
| **Data** | CSV gem for import |
| **Deploy** | Kamal, Docker; Thruster (optional) |

*หมายเหตุ: ไม่ใช้ Bootstrap; UI ใช้ Design System ใน repo (design_tokens.css + application.css + ODT components).*

---

## Technical Design

### High-level architecture
- **Controllers** — Thin; filter/params ใน controller, โหลดข้อมูลสำหรับ view; Export สร้าง `ExportJob` แล้ว enqueue job
- **Services** — Business logic และ side effects: `CustomerSyncService`, `Exports::*` (PDF/Excel), `PromotionPerformanceQuery`, `Promotions::MetricsService`, `Customers::DirectoryQuery`
- **Jobs** — `GenerateExportJob`: อ่าน export_type/format, เรียก service ที่ตรงกัน, อัปเดต state ของ `ExportJob`
- **Policies** — Pundit สำหรับ Export (และอื่นๆ ถ้ามี)
- **Helpers** — `ApplicationHelper`, `Admin::CustomersHelper`, `Admin::SettingsHelper`, `Odt::UiHelper` (buttons, badges, KPI strip, page header, etc.)
- **View structure** — Layouts: `application`, `admin`, mailer; Partials ใต้ `admin/`, `components/odt/`, `shared/`, `finance_dashboards/`; Turbo Frames สำหรับ modal และ partial updates (e.g. Customer sync, Export modal)

### Key directories
```
app/
  controllers/application_controller.rb
  controllers/admin/          # dashboard, finance, training_classes, attendees,
                              # customers, settings, class_expenses, exports, data, components
  controllers/finance_dashboards_controller.rb
  models/                     # TrainingClass, Attendee, Customer, Promotion, AttendeePromotion,
                              # ClassExpense, AdminUser, ExportJob, CustomField, CustomFieldValue
  services/                   # customer_sync_service, exports/*, promotions/*, customers/*
  jobs/                       # generate_export_job
  policies/                   # export_job_policy
  helpers/                    # application_helper, admin/*, odt/ui_helper
  views/
    layouts/                  # application, admin, mailer
    components/odt/           # shared UI: page_header, kpi_strip, button, card, badge, table, etc.
    admin/                    # dashboard, finance, training_classes, attendees, customers,
                              # settings, class_expenses, exports, data
    finance_dashboards/       # CFO dashboard partials
    shared/                   # empty_state, section_header, progress_bar, etc.
  assets/stylesheets/          # design_tokens.css, application.css
  assets/javascripts/          # table_sort_filter; Stimulus controllers under javascript/controllers
```

### Export flow
1. User เลือก type/format ใน Export modal (HTML request ใช้ `file_format` ไม่ใช้ `format`).
2. `Admin::ExportsController#create` สร้าง `ExportJob` (state: queued), enqueue `GenerateExportJob`.
3. Job เรียก service ตาม type+format (e.g. `Exports::FinancialReportPdf`), attach ไฟล์กับ `ExportJob`, อัปเดต state เป็น succeeded/failed.
4. Exports index แสดงรายการ; user ดาวน์โหลดจาก link เมื่อ state = succeeded.

### Customer 360° & Edit
- **Show** — Sticky header, 2-column layout (Billing/Tax, Snapshot; Class history, Documents/Payments; Timeline); optional auto-sync billing เมื่อข้อมูล billing ขาด; Turbo Stream สำหรับ sync
- **Edit** — 2-column form (Basic info, Billing/Tax) + side panel (tips by type, document preview); "Sync from latest registration" ใช้ `link_to` + `turbo_method: :post` และ Turbo Stream แทน nested form

---

## Database

### Main tables (from schema)

| Table | Purpose |
|-------|---------|
| **admin_users** | email, password_digest — ผู้ดูแลระบบ |
| **training_classes** | title, date, end_date, location, start_time, end_time, instructor, max_attendees, price, cost, description |
| **attendees** | training_class_id, customer_id, name, email, phone, company, participant_type, seats, source_channel, status (attendee/potential), payment_status, document_status, attendance_status, total_classes, price, total_amount, invoice_no, due_date, quotation_no, receipt_no, tax_id, address, name_thai, notes |
| **customers** | name, email, phone, participant_type, company, tax_id, billing_name, billing_address |
| **attendee_promotions** | attendee_id, promotion_id |
| **promotions** | name, discount_type, discount_value, description, active, base_price |
| **class_expenses** | training_class_id, description, amount, category |
| **export_jobs** | export_type, format, state, filters, include_sections, include_custom_fields, requested_by_id, started_at, finished_at, error_message, filename; has_one_attached :file |
| **custom_fields** | entity_type, key, label, field_type, active |
| **custom_field_values** | custom_field_id, record_type, record_id, value |
| **active_storage_*** | blobs, attachments, variant_records — ไฟล์อัปโหลด (สลิป, export files) |

### Relationships (summary)
- `TrainingClass` has_many `attendees`, has_many `class_expenses`
- `Attendee` belongs_to `training_class`, optional belongs_to `customer`; has_many attendee_promotions, has_many promotions through attendee_promotions; has_one_attached payment_slips (or payment_slip)
- `Customer` has_many `attendees`
- `ExportJob` belongs_to requested_by (AdminUser); has_one_attached :file
- `CustomFieldValue` belongs_to custom_field, polymorphic (record)

---

## Design System

UI ใช้ CSS แบบรวมศูนย์ ไม่ใช้ Bootstrap: ตัวแปรและคอมโพเนนต์อยู่ที่ `app/assets/stylesheets/` และ `app/views/components/odt/`.

### Design tokens (`design_tokens.css`)

- **Font**  
  `--font-family`: Inter + system fallbacks (ใช้ทั้ง body และหัวข้อใน application.css)

- **Typography scale**  
  `--font-size-xs` (11px) ถึง `--font-size-4xl` (28px) — ใช้กับ body, headings, labels, table cells ให้ตรงกันทุกหน้า

- **Colors**  
  `--color-ink`, `--color-primary`, `--color-surface`, `--odt-blue`, `--odt-yellow`, `--odt-muted`, `--odt-blue-tint`, `--odt-yellow-tint`

- **Spacing**  
  `--space-1` (4px) ถึง `--space-6` (32px)

- **Radii & shadows**  
  `--radius-xs`, `--radius-sm`, `--radius-md`; `--shadow-sm`, `--shadow-md`; `--border-light`, `--border-muted`

### Application CSS (`application.css`)

- ใช้ tokens สำหรับ `body`, `h1`–`h6`, `.odt-page-header`, `.admin-section`, `.odt-section-header`, Customer 360, Customer Edit, Export modal, KPI strip และส่วนอื่นที่ต้องการให้ฟอนต์/ขนาดตรงกันทุกหน้า

### Components (ODT)

- **Page / section** — `page_header`, `section_header` (title + optional actions)
- **Metrics** — `kpi_strip` (icon + label บรรทัดเดียว, ค่าตัวเลขชิดขวา), `metric_card`, `metric`
- **UI** — `button`, `badge`, `card`, `accent_card`, `icon_button`, `action_menu`
- **Data** — `table`, `table_empty_state`, `amount_cell`, `doc_chip`
- **Shared** — `empty_state`, `progress_bar`, `section_header` (shared)

การจัด style กล่อง KPI และหน้าอื่นให้ใช้ class เหล่านี้ร่วมกับ tokens เพื่อให้ Font type และ Font size ตรงกันทุกหน้า

---

## Setup Instructions

### Prerequisites
- Ruby 3.x
- Rails 8.1.x
- SQLite3
- Bundler

### Installation
1. `bundle install`
2. `rails db:create && rails db:migrate && rails db:seed`
3. (Optional) วาง CSV ใน `db/Data/` แล้วรัน `rails data:import`
4. `rails server` แล้วเปิด `http://localhost:3000`

### Background jobs
Export ใช้ Active Job; ถ้าใช้ Solid Queue ให้รัน worker (หรือเทียบเท่า) เพื่อให้ export jobs ทำงาน

---

## Development

- **Tests:** `rails test`
- **Console:** `rails console`
- **Rake:** `rails data:import`, `rails attendees:migrate` (ถ้ามี)

---

## License

This project is open source and available for use.
