# ODT Training Management — Requirements Specification

เอกสารนี้อธิบายความต้องการของระบบแบบละเอียด (Functional + Non-Functional) สำหรับทีมพัฒนา ผู้ดูแลผลิตภัณฑ์ และผู้บูรณาการ  
This document details functional and non-functional requirements for developers, product owners, and integrators.

**Document version:** 1.0  
**Last updated:** 2026-03-16  
**Application:** ODT Training Management (Rails monolith)

---

## 1. Purpose & scope

### 1.1 Purpose
- รวม workflow การจัดอบรม ลูกค้า การเงิน การส่งออก และรายงาน ไว้ในเว็บแอปเดียว  
- ลดการพึ่งพา spreadsheet สำหรับงานปฏิบัติการหลัก (รายชื่อผู้เข้าอบรม สถานะการชำระ ฯลฯ)

### 1.2 In scope
- จัดการคลาสอบรม ปฏิทิน ผู้เข้าอบรม ลูกค้า โปรโมชัน ค่าใช้จ่ายคลาส  
- โมดูลการเงิน (ภาพรวม ลูกหนี้ การชำระเงิน สลิป ใบเสร็จ ฯลฯ)  
- Insights / Clients / Strategy dashboards ตามที่ implement ในแอป  
- ระบบ Export (PDF/Excel) แบบ background job  
- งบประมาณ (Budget) ตาม routes ที่มี  
- หน้า Public สำหรับคลาสที่เปิดเผยได้

### 1.3 Out of scope (unless added later)
- Multi-tenant SaaS แยกองค์กร  
- Mobile native app  
- Role-based permission ละเอียดหลายระดับบน `admin_users` (ในโค้ดปัจจุบันเน้น Devise + Pundit เฉพาะบาง resource)

---

## 2. Actors & access

| Actor | การเข้าถึง | หมายเหตุ |
|--------|-------------|----------|
| Admin user | เข้าสู่ระบบผ่าน Devise (`/admin` และ path ย่อย) | Session-based |
| Public visitor | ดูหน้า public class (`/classes/:public_slug`) | ไม่ต้อง login |

---

## 3. High-level architecture (logical)

- **Web UI:** Rails views + Hotwire (Turbo Drive / Frames / Streams) + Stimulus  
- **Domain logic:** Models + PORO services ใต้ `app/services/`  
- **Async:** Active Job + Solid Queue (exports, อีเมลบางประเภท)  
- **Files:** Active Storage (สลิป ฯลฯ)  
- **DB:** SQLite (development/default; production อาจเปลี่ยนตาม deploy)

---

## 4. Functional requirements by module

รหัสใช้อ้างอิงใน README และในการทดสอบ (traceability)

### 4.1 Operations

| ID | Requirement | Priority | Acceptance notes |
|----|-------------|----------|------------------|
| OPS-1 | CRUD คลาสอบรม (หัวข้อ วันที่ เวลา สถานที่ วิทยากร ที่นั่ง ราคา ต้นทุน คำอธิบาย สถานะ ฯลฯ) | Must | บันทึกใน `training_classes` |
| OPS-2 | รายการคลาสพร้อมตัวกรองและ KPI strip | Must | หน้า `/admin/training_classes` |
| OPS-3 | Training Calendar (`/operations/training_calendar`): month/week, การ์ดอีเวนต์, ตัวกรอง | Must | Turbo frames สำหรับ drawer/modal ตาม implement |
| OPS-4 | Panel/drawer: รายละเอียดคลาส การทำงานด่วน (ดู แก้ไข ฯลฯ) | Must | |
| OPS-5 | Course catalog + sync | Should | `/admin/courses` |
| OPS-6 | Instructors index | Must | จากข้อมูลคลาส |
| OPS-7 | ผู้เข้าอบรมรายคลาส: เพิ่ม/แก้/ลบ; สถานะ attendee / potential; ย้ายสถานะ | Must | nested under `training_classes` |
| OPS-8 | Export CSV/เอกสาร; ส่งอีเมล (รายคน/ทั้งคลาส); sync ภาษีจาก customer | Must | |
| OPS-9 | Class workspace: overview, attendees, leads, documents, finance, attendance, edit | Must | `/admin/classes/:id/*` |
| OPS-10 | **Attendee ledger (class workspace):** ตารางผู้เข้าอบรมแบบปฏิบัติการ — กรอง (All/Corporate/Individual), ค้นหา, คลิกเพื่อแก้ Seats / Source / Payment / Amount; bulk: mark paid, reminder, เปลี่ยน source | Must | `PATCH quick_update`, `POST bulk_update`; Stimulus `ledger-cell-edit` |
| OPS-11 | Training calendar: วันที่ “วันนี้” แสดงเป็นวงกลมชัดเจน | Should | `training_calendar.css` |

### 4.2 Clients

| ID | Requirement | Priority | Acceptance notes |
|----|-------------|----------|------------------|
| CLT-1 | Customer directory CRUD + search | Must | `/admin/customers` |
| CLT-2 | Customer 360°: billing/tax snapshot ประวัติคลาส เอกสาร/การชำระ timeline | Must | |
| CLT-3 | Export ข้อมูลลูกค้า / billing / template | Must | |
| CLT-4 | Corporate accounts | Should | `/clients/corporate_accounts` |
| CLT-5 | Client analysis | Should | `/clients/analysis` |
| CLT-6 | Sync duplicates, merge, register for class | Should | |

### 4.3 Financials

| ID | Requirement | Priority | Acceptance notes |
|----|-------------|----------|------------------|
| FIN-1 | Financial overview + Turbo filters | Must | `/financials/overview` |
| FIN-2 | Accounts receivable | Must | `/financials/accounts_receivable` |
| FIN-3 | Payments: index/show, summary PDF, verify/reject slip, issue receipt, bulk | Must | `/financials/payments` |
| FIN-4 | Expenses listing | Must | `/financials/expenses` |
| FIN-5 | Compliance (placeholder ได้) | Should | `/financials/compliance` |
| FIN-6 | Export history | Must | `/financials/export_history` |
| FIN-7 | VAT & pricing ตามกฎธุรกิจ (เช่น VAT 7%, ราคาต่อหัว corporate) | Must | สอดคล้อง `Attendee` / คลาส |
| FIN-8 | Redirect จาก legacy `/finance/*` → `/financials/*` | Must | `routes.rb` |

### 4.4 Insights

| ID | Requirement | Priority |
|----|-------------|----------|
| INS-1 | Business insights dashboard | Must |
| INS-2 | Financial insights entry | Must |
| INS-3 | Strategy insights entry | Must |
| INS-4 | Action center | Must |

### 4.5 Strategy

| ID | Requirement | Priority |
|----|-------------|----------|
| STR-1 | Promotions CRUD + หลายโปรต่อผู้สมัครได้ | Must |
| STR-2 | Promotion performance (KPI, donut, drilldown, export) | Must |

### 4.6 Budget (internal)

| ID | Requirement | Priority | Acceptance notes |
|----|-------------|----------|------------------|
| BUD-1 | Budget module ภายใต้ `/budget/*` (years, overview, staff forecast, worklogs, setup, expenses, events ฯลฯ) | Should | ตาม `config/routes.rb` |
| BUD-2 | เอกสารเชื่อม `docs/BUDGET_INTEGRATION.md` | Should | |

### 4.7 Exports & admin data

| ID | Requirement | Priority |
|----|-------------|----------|
| EXP-1 | Export ผ่าน `ExportJob` + background job เท่านั้น | Must |
| EXP-2 | PDF/Excel ชุดที่ implement (Financial, Class, Customer ฯลฯ) | Must |
| EXP-3 | Audit: `requested_by`, state, ดาวน์โหลดเมื่อสำเร็จ | Must |
| ADM-1 | Admin dashboard, data upload/download pages | Must |
| ADM-2 | Public class landing | Must |

### 4.8 Auth & security

| ID | Requirement | Priority |
|----|-------------|----------|
| AUTH-1 | Admin login (Devise) | Must |
| AUTH-2 | Authorization (Pundit) ตาม policy ที่มี | Must |
| SEC-1 | CSRF protection บนฟอร์ม; ไม่เปิดเผยข้อมูลลับใน log โดยไม่จำเป็น | Must |

### 4.9 Payment summary & bank details (customer-facing copy)

| ID | Requirement | Priority |
|----|-------------|----------|
| PAY-1 | Payment summary / PDF แสดงช่องทางโอน: ธนาคาร ประเภทบัญชี เลขที่บัญชี ชื่อบัญชี ตามค่าที่กำหนดใน partial/service | Must | ดู `financials/payments/_payment_summary`, `payment_summary_pdf_generator` |

---

## 5. Non-functional requirements (detailed)

### 5.1 Performance
- งานหนัก (PDF/Excel ใหญ่) ต้องไม่บล็อก request หลัก — ใช้ Active Job  
- UI ใช้ Turbo เพื่อลด full reload ในจุดที่เหมาะสม

### 5.2 Reliability
- Export job ต้องอัปเดต state ชัดเจน (queued / succeeded / failed)  
- ควรมี path ดาวน์โหลดเมื่อสำเร็จ

### 5.3 Maintainability
- UI หลักใช้ design tokens + ODT components (`components/odt`, `Odt::UiHelper`)  
- หลีกเลี่ยงสี/ระยะแบบ magic ใน component — อ้างอิง `design_tokens.css` / `:root`

### 5.4 Usability & accessibility
- ตาราง admin รองรับ scroll แนวนอนบนจอแคบ  
- ปุ่มหลัก/รองสอดคล้องชุด `odt-btn`  
- Focus states และ semantic HTML ตาม `docs/ui-checklist.md`

### 5.5 Compatibility
- เบราว์เซอร์สมัยใหม่ (Chrome, Safari, Firefox, Edge)  
- Front-end: Importmap + Stimulus; ไม่บังคับ Node build สำหรับ runtime

### 5.6 Deployability
- รองรับ Docker/Kamal ตามที่ระบุใน Gemfile  
- ต้องรัน worker สำหรับ Solid Queue ใน production หากใช้ export/ job จริง

---

## 6. Data model (summary)

หลัก: `TrainingClass`, `Attendee`, `Customer`, `Promotion`, `AttendeePromotion`, `ClassExpense`, `ExportJob`, `AdminUser`, `FinancialActionLog`, custom fields, Active Storage attachments.

รายละเอียดความสัมพันธ์: `docs/DATABASE_ER_DIAGRAM.md`

---

## 7. UI / brand

- ธีม ODT: navy primary, yellow accent, พื้นหลังอ่อน  
- ตาราง ledger: หัวตารางสีเข้ม + accent เส้นล่าง  
- ไม่ใช้ Tailwind เป็นหลัก; **Bootstrap 5** โหลดใน admin layout สำหรับ grid/utility บางส่วน — สไตล์หลักอยู่ที่ CSS ของโปรเจกต์ (ODT)

---

## 8. Related documentation

| File | Content |
|------|---------|
| `README.md` | Overview, setup, status, short requirement table |
| `docs/NAVIGATION_IA.md` | Information architecture & routes |
| `docs/ui-checklist.md` | UI review checklist |
| `docs/ui-consistency.md` | Consistency rules |
| `docs/DATABASE_ER_DIAGRAM.md` | ER reference |
| `docs/BUDGET_INTEGRATION.md` | Budget integration |
| `docs/INSIGHTS_*.md`, `docs/CLIENTS_*.md` | Feature notes |

---

## 9. Traceability & change control

- เมื่อเพิ่มฟีเจอร์ใหม่: อัปเดต **README** (สถานะ + ตารางสั้น) และ **เอกสารฉบับนี้** (ID ใหม่ + acceptance)  
- เวอร์ชันเอกสาร: เพิ่มเลข minor เมื่อแก้ requirement ที่มีผลต่อทดสอบ

---

## Appendix A — Key URLs (quick reference)

| Area | Path |
|------|------|
| Training classes | `/admin/training_classes` |
| Class workspace | `/admin/classes/:id` |
| Class attendees | `/admin/classes/:id/attendees` |
| Training calendar | `/operations/training_calendar` |
| Financials overview | `/financials/overview` |
| Payments | `/financials/payments` |
| Insights | `/insights/business` |
| Clients analysis | `/clients/analysis` |
| Budget | `/budget` |
| Root | `/` → redirect training classes |

---

## Appendix B — Attendee ledger API (admin)

| Method | Path | Purpose |
|--------|------|---------|
| PATCH | `/admin/training_classes/:training_class_id/attendees/:id/quick_update` | Inline edit (Turbo Stream row replace) |
| POST | `/admin/training_classes/:training_class_id/attendees/bulk_update` | Bulk: mark paid, reminder mailto, change source |

Parameters ที่รองรับขึ้นกับ `Admin::AttendeesController#quick_update` / `#bulk_update` implementation.

---

*End of Requirements Specification*
