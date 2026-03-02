# ODT Training Management System

Internal Training Management System for managing public and corporate training classes, attendees, customers, promotions, finance, and exports. Built with **Ruby on Rails** and **Turbo** for a modern, responsive admin experience. Replaces spreadsheet-based workflows with a unified web UI, design system, and background export jobs.

---

## Table of Contents

- [Current project status](#current-project-status)
- [Business Features](#business-features)
- [Technical Design](#technical-design)
- [Design Principles](#design-principles)
- [Design System](#design-system)
- [Project Structure](#project-structure)
- [Knowledge & Documentation](#knowledge--documentation)
- [Setup & Development](#setup--development)

---

## Current project status

**Summary:** The ODT Training Management System is in active development with core operations, financials, insights, and client modules implemented and wired to the UI.

### Implemented

| Area | Status | Notes |
|------|--------|--------|
| **Operations** | ✅ | Training classes CRUD; Training Calendar at `/operations/training_calendar` (month view, drawer, quick add, filters); class workspace (overview, attendees, leads, documents, finance, edit); courses index/show/edit/sync; instructors index. |
| **Attendees** | ✅ | Per-class attendees; status (attendee/potential); move between statuses; export CSV/documents; send email (per attendee or whole class); sync tax from customer; pricing and document sections. |
| **Clients** | ✅ | Customer directory (index, show, new, create, edit, update); Customer 360° (billing/tax, export customer info/billing/template); corporate accounts (`/clients/corporate_accounts`); client analysis (`/clients/analysis`); sync duplicates, merge, register for class. |
| **Financials** | ✅ | Financial overview at `/financials/overview` (KPIs, charts, trend, action items); accounts receivable; payments (index, show, summary PDF, verify/reject slip, issue receipt, bulk actions); expenses; compliance; export history. Legacy `/finance/*` redirects to `/financials/*`. |
| **Insights** | ✅ | Business (`/insights/business`), Financial, Strategy, Actions dashboards with queries and UI. |
| **Strategy** | ✅ | Promotions CRUD under `/admin/settings`; promotion performance (revenue share, drilldown, export). |
| **Exports** | ✅ | ExportJob + `GenerateExportJob`; PDF (Financial Report, Class Report, Customer Summary) and Excel exports; export history and download. |
| **Admin** | ✅ | Dashboard; data (financial report, customer info, attendee list, upload); exports; settings; design system components at `/admin/components`. |
| **Public** | ✅ | Public class landing at `/classes/:public_slug`. |
| **Auth** | ✅ | Admin authentication via **Devise** (Gemfile); Pundit for authorization (e.g. ExportJob). |

### Database

Schema is current: `admin_users`, `training_classes`, `attendees`, `customers`, `courses`, `promotions`, `attendee_promotions`, `class_expenses`, `export_jobs`, `custom_fields`, `custom_field_values`, `financial_action_logs`, Active Storage. Migrations through `20260223060000` (e.g. VAT-related and custom fields).

### Tests

Unit and integration tests cover controllers (insights, financials, clients, admin exports/customers/settings/class_expenses), services (insights, clients, exports), models (customer, promotion, class_expense), and mailers (attendee, payment). Run with `rails test`.

### Tech stack (current)

| Layer | Technology |
|-------|------------|
| Framework | Ruby on Rails 8.1.x |
| Ruby | 3.x |
| Database | SQLite3 |
| Server | Puma |
| Assets | Propshaft, CSS (no Tailwind, no Bootstrap) |
| Frontend | Turbo (Frames, Streams), Stimulus, Importmap |
| Auth | Devise (admin) |
| Authorization | Pundit |
| Background jobs | Active Job + Solid Queue |
| File storage | Active Storage (local); image_processing for variants |
| Export | Prawn, Prawn-Table, CombinePDF (PDF); caxlsx, caxlsx_rails (Excel) |
| Charts | ApexCharts (insights), Flowbite (donuts), custom CSS |
| Deploy | Kamal, Docker; Thruster optional |

---

## Business Features

### Operations
- **Training Classes** — Create, edit, delete classes (date, end_date, start_time, end_time, location, instructor, max_attendees, price, cost, description). List with filters and KPI strip.
- **Training Calendar** — Month/week view at `/operations/calendar`; ODT-themed event cards, filters (instructor, location, status, type, nearly full), KPIs (total classes, seats sold, revenue forecast), side panel with class details and quick actions (View, Edit, Duplicate, Cancel). Logo in navbar links to Calendar.
- **Courses** — Course catalog; sync from external source; link to classes.
- **Instructors** — Index of instructors derived from training classes.
- **Attendees** — Per-class: add/edit/remove attendees; status Attendee / Potential; move between statuses; export CSV/documents; send email (per attendee or whole class); sync tax from customer.

### Insights
- **Business Insights** — Performance and decision support (dashboard-style).
- **Financial Insights** — Links to Financial Overview.
- **Strategy Insights** — Links to Promotions / settings.
- **Action Center** — Links to dashboard action-required and opportunities.

### Clients
- **Client Directory** — Customer list; search; edit; Customer 360° view (billing/tax, snapshot, class history, documents/payments, activity timeline); export (customer info, billing for accounting, template).
- **Corporate Accounts** — Corporate segment view; company-level aggregation.
- **Client Analysis** — Revenue by channel, segment donuts, top spenders, conversion, risk (no activity, concentration).

### Financials
- **Financial Overview** — CFO-style dashboard: Turbo filters, cash flow, AR aging, corporate ledger, documents compliance, revenue composition, expense summary.
- **Accounts Receivable** — AR list and actions.
- **Payment Tracking** — Payments list; payment show with PDF download and send summary.
- **Expense Control** — Class expenses index.
- **Compliance** — Compliance placeholder.
- **Export History** — Audit of export jobs (requested_by, state, download when succeeded).

### Strategy
- **Promotions** — CRUD; percentage, fixed amount, buy-x-get-y; multiple promotions per attendee.
- **Promotion Performance** — KPIs, revenue share (donut), leaderboard, drilldown/export.

### Core Capabilities (cross-cutting)
- **Customer 360° & Edit** — Sticky header, billing/tax, snapshot, class history, documents/payments, timeline; edit with “Sync from latest registration”; Turbo Streams for sync.
- **Payment & Documents** — QT/INV/Receipt; upload payment slips (PNG, JPG, GIF, PDF); invoice_no, due_date.
- **Class Expenses** — Per-class expenses (category, amount).
- **VAT & Pricing** — Pre-VAT price, VAT 7%, total; price per head for corporate.
- **Export System** — PDF (Financial Report, Class Report, Customer Summary), Excel (Financial, Class Attendees, Customer Master, etc.); background jobs (Solid Queue); audit (requested_by_id).
- **Custom Fields** — Entity-based custom fields and values for exports and forms.
- **Admin Auth** — Devise for admin authentication; Pundit for authorization (e.g. ExportJob).

---

## Technical Design

### High-level architecture
- **Controllers** — Thin: params/filters in controller, load data for view. Export creates `ExportJob` and enqueues `GenerateExportJob`.
- **Services** — Business logic and side effects: `CustomerSyncService`, `Exports::*` (PDF/Excel), `PromotionPerformanceQuery`, `Promotions::MetricsService`, `Customers::DirectoryQuery`, `Clients::CorporateAccountsInsights`, `Insights::*` (business, financial, strategy, action center), `Finance::FinanceDashboardSummary`, `FinancialOverviewService`.
- **Jobs** — `GenerateExportJob` (reads export_type/format, calls matching export service, attaches file to ExportJob, updates state). `SendPaymentSummaryJob` for payment summary emails.
- **Policies** — Pundit (e.g. `ExportJobPolicy`). `current_user` from Devise; no role column on admin_users (role-based UI deferred).
- **Helpers** — `ApplicationHelper`, `Admin::CustomersHelper`, `Admin::SettingsHelper`, `Odt::UiHelper` (buttons, badges, KPI strip, page header, table, filters).
- **Frontend** — Turbo Frames and Turbo Streams for modals, side panels, and partial updates (e.g. calendar event panel, customer sync, export modal). Stimulus for interactive bits. No Bootstrap; ODT design system (CSS only).

### Key routes (summary)
| Area | Paths |
|------|--------|
| **Operations** | `/operations/calendar`, `/operations/calendar/event/:id`; `/admin/training_classes`, `/admin/courses`, `/instructors` |
| **Insights** | `/insights`, `/insights/business`, `/insights/financial`, `/insights/strategy`, `/insights/actions` |
| **Clients** | `/admin/customers`, `/clients/corporate_accounts`, `/clients/analysis` |
| **Financials** | `/finance`, `/finance/ar`, `/finance/payments`, `/finance/expenses`, `/finance/compliance`, `/finance/export_jobs`; `/financials/payment_tracking`, `/financials/payments/:id` |
| **Strategy** | `/admin/settings` (Promotions, Performance) |
| **Admin** | `/admin` (dashboard), `/admin/data`, exports, etc. |

Root redirects to `/admin/training_classes`. Logo links to `/operations/calendar`.

### Export flow
1. User chooses export type and format in Export modal (e.g. Financial Report PDF).
2. `Admin::ExportsController#create` creates `ExportJob` (state: queued), enqueues `GenerateExportJob`.
3. Job calls the appropriate `Exports::*` service, attaches file to `ExportJob`, sets state to succeeded/failed.
4. Export History lists jobs; user downloads when state = succeeded.

### Database (main tables)
- **admin_users** — email, password_digest
- **training_classes** — title, date, end_date, start_time, end_time, location, instructor, max_attendees, price, cost, description
- **attendees** — training_class_id, customer_id, name, email, seats, participant_type, status (attendee/potential), payment_status, document_status, pricing fields, invoice_no, due_date, etc.
- **customers** — name, email, company, billing_*, tax_id, acquisition_channel
- **promotions**, **attendee_promotions** — discount rules and application
- **class_expenses** — training_class_id, description, amount, category
- **export_jobs** — export_type, format, state, filters, requested_by_id, file (Active Storage)
- **custom_fields**, **custom_field_values** — polymorphic custom data
- **financial_action_logs** — audit for financial actions

---

## Design Principles

1. **Token-first** — Colors, spacing, typography, radii, and shadows come from design tokens (`design_tokens.css`, `application.css` :root). Avoid new hex/rgba in component CSS.
2. **Component reuse** — Use shared ODT components (page header, section header, cards, KPI strip, filters, tables, buttons). See `docs/ui-checklist.md`.
3. **Hierarchy** — Header → Summary (KPIs) → Operations (tables, forms). No heavy solid backgrounds; use accent borders and strips.
4. **Consistency** — Same font family and scale across pages; tables use ODT table pattern; primary actions use primary button style.
5. **Minimal layout** — Prefer existing layout classes (e.g. dashboard grid, finance two-col) over one-off wrappers.
6. **Accessibility** — Focus states, ARIA where needed, semantic HTML.

### Design approach

- **Theme:** Consulting-premium, enterprise SaaS. Primary dark text, navy primary, yellow accent, light gradient background.
- **Layout:** Single font family (Inter); typography scale from 11px (xs) to 28px (4xl); fixed card radius (e.g. 12–16px), consistent section spacing (48–56px).
- **Tables:** Navy header with yellow left accent and bottom border; row hover with blue tint; no inline hex in component rules.

---

## Design System

**ODT** (brand) theme: consulting-premium, enterprise SaaS look. No Tailwind; no Bootstrap. All UI via `design_tokens.css`, `design_system.css`, and `application.css`.

### Tokens (`design_tokens.css` + `application.css` :root)

- **Font** — `--font-family`: Inter + system fallbacks.
- **Typography** — `--font-size-xs` (11px) through `--font-size-4xl` (28px); see design_tokens.css for full scale.
- **Spacing** — `--space-1` (4px) to `--space-6` (32px); `--odt-spacing` (24px), `--odt-section` (48px), `--odt-section-lg` (56px); `--page-main-padding-top/left`.
- **Radii** — `--radius-xs` (6px), `--radius-sm` (8px), `--radius-md` (12px); `--odt-radius` (16px in application).
- **Shadows** — `--shadow-sm`, `--shadow-md`; `--odt-shadow`, `--odt-shadow-hover`.
- **Borders** — `--border-light`, `--border-muted`; table: `--table-header-border-left` (accent), `--table-header-border-bottom`.

### สี (Colors)

| Token | Hex | Usage |
|-------|-----|--------|
| **Primary / Navy** | `#13139c` | Primary actions, links, left accent bars |
| **Deep Navy** | `#012a71` | Table header bg in some views |
| **Accent / Gold** | `#ffc700` | Table header border, highlights, FULL badge |
| **Gold soft** | `#f5bf00` | Softer accent variant |
| **Yellow (ODT)** | `#F5C400` | Alternate yellow in tokens |
| **Ink / Dark** | `#292929` | Body text, headings |
| **Muted** | `#6b7280` | Labels, secondary text |
| **Surface** | `#E4ECFD` | Card/surface; gradient: `#FFFFFF` → `#F7F9F0` → `#E4ECFD` |
| **Background** | `#f9f9fe` | Page/card (--odt-bg, --odt-soft) |
| **Tints** | `rgba(19,19,156,0.06)` | Row/button hover (--odt-blue-tint) |
| **Success** | `#059669` | Success states, badges |
| **Warning** | `#f59e0b` / `#d97706` | Warning states |
| **Danger** | `#dc2626` | Errors, danger actions |

### Components (`design_system.css` + `application.css` + `components/odt/`)

- **Page / section** — `.page-header`, `.section-header`; left accent bar (4px primary).
- **Cards** — `.card`, `.card--accent-left`; `.card__header`, `.card__title`, `.card__body`; `.odt-stat-card`, `.odt-card-v1`.
- **Buttons** — `.btn`, `.btn--primary`, `.btn--secondary`, `.btn--danger`, `.btn--ghost`, `.btn--sm`; `.icon-btn`, `.icon-btn--primary`.
- **KPI / metrics** — `.kpi-strip`, `.kpi` (`.kpi__label`, `.kpi__value`); `.kpi--danger`, `.kpi--success`, `.kpi--warning`.
- **Tables** — `.data-table-wrap`, `.data-table`; column classes `.col-xs` … `.col-xl`; `.cell--truncate`, `.cell--num`, `.cell-actions`.
- **Filters** — `.filters`, `.filters__group`, `.filters__label`, `.filters__input`, `.filters--compact`.
- **Tabs** — `.tabs`, `.tabs__tab`; `.subtabs`, `.subtabs__tab`.
- **Badges** — `.badge`, `.badge--success`, `.badge--warning`, `.badge--info`, `.badge--neutral`, `.badge--danger`.
- **Empty states** — `.empty-state`, `.empty-state__icon`, `.empty-state__title`, `.empty-state__hint`, `.empty-state__cta`.
- **Other** — `.queue`, `.mini-list`, `.meter-bar`, `.meter-bar-row`, `.grid-2`, `.modal-content--ds`, form groups.
- **Calendar** — Training Calendar: `cal-*` / `tc-*`; event cards with left accent, progress bar, FULL badge; drawer/side panel.

### Where to add styles
- **New tokens** — Add in `:root` in `design_tokens.css` or the style-audit block in `application.css`; do not introduce one-off hex in component rules.
- **New components** — Add a named block (e.g. “ODT [ComponentName]”) and use tokens only. See `docs/ui-checklist.md`.

---

## Project Structure

```
Training-Management/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── admin/                    # dashboard, finance, training_classes, attendees,
│   │   │                             # customers, settings, exports, data, courses, etc.
│   │   ├── clients/                  # corporate_accounts, analysis
│   │   ├── financials/               # payment_tracking, payments
│   │   ├── finance_dashboards_controller.rb
│   │   ├── insights/                 # business, financial, strategy, actions
│   │   └── operations/              # calendar (Training Calendar)
│   ├── models/                      # TrainingClass, Attendee, Customer, Promotion,
│   │                                 # AttendeePromotion, ClassExpense, AdminUser,
│   │                                 # ExportJob, CustomField*, FinancialActionLog
│   ├── services/                    # CustomerSyncService, Exports::*, Promotions::*,
│   │   ├── clients/                 # CorporateAccountsInsights, DateRangeResolver
│   │   ├── insights/                # BusinessInsights, FinancialInsights, etc.
│   │   └── payment_summary_pdf_generator.rb
│   ├── jobs/                        # GenerateExportJob, SendPaymentSummaryJob
│   ├── policies/                    # ExportJobPolicy, etc.
│   ├── helpers/                     # ApplicationHelper, Admin::*, Odt::UiHelper
│   ├── views/
│   │   ├── layouts/                 # application, admin, mailer
│   │   ├── components/odt/          # page_header, kpi_strip, button, card, table, filters
│   │   ├── shared/                  # main_nav, section_header, empty_state, tabs
│   │   ├── admin/                   # dashboard, training_classes, attendees, customers,
│   │   │                             # settings, exports, finance, data
│   │   ├── operations/calendar/     # index, month/week grid, event_card, event_sidebar
│   │   ├── finance_dashboards/      # CFO dashboard partials
│   │   ├── financials/              # payment_tracking, payments
│   │   ├── insights/                # business, financial, strategy, actions
│   │   ├── clients/                 # corporate_accounts, analysis
│   │   └── payment_mailer/
│   ├── assets/stylesheets/          # design_tokens.css, design_system.css, application.css
│   └── javascript/controllers/    # Stimulus controllers
├── config/
│   └── routes.rb                    # Executive IA routes (insights, finance, operations, clients)
├── db/
│   ├── schema.rb
│   └── migrate/
├── docs/                            # NAVIGATION_IA, INSIGHTS_*, CLIENTS_*, ui-checklist,
│   ├── NAVIGATION_IA.md             # DATABASE_ER_DIAGRAM, etc.
│   ├── ui-checklist.md
│   ├── ui-consistency.md
│   └── ...
├── test/                            # Unit and integration tests
└── README.md
```

---

## Knowledge & Documentation

| Document | Purpose |
|----------|---------|
| **docs/NAVIGATION_IA.md** | Top-level menu (Operations, Insights, Clients, Financials, Strategy, Settings); route map; manual test checklist. |
| **docs/ui-checklist.md** | Pre-merge UI checklist: shared components, KPIs, tokens, tables, responsive layout. |
| **docs/ui-consistency.md** | UI consistency guidelines. |
| **docs/INSIGHTS_DISCOVERY.md** | Insights feature discovery and implementation notes. |
| **docs/INSIGHTS_IMPLEMENTATION.md** | Insights implementation details. |
| **docs/CLIENTS_DISCOVERY.md** | Clients/Corporate Accounts discovery and decisions. |
| **docs/CLIENTS_IMPLEMENTATION.md** | Clients implementation details. |
| **docs/DATABASE_ER_DIAGRAM.md** | Database entity-relationship reference. |

**Conventions**
- **Calendar** — Month default; filters via query params; event cards constrained (no overflow); side panel via Turbo Frame.
- **Exports** — Always via ExportJob + background job; never synchronous heavy PDF/Excel in request.
- **Customer sync** — “Sync from latest registration” and sync endpoints use Turbo Streams where appropriate.

---

## Setup & Development

### Tech stack

| Layer | Technology |
|-------|------------|
| Framework | Ruby on Rails 8.1.x |
| Ruby | 3.x |
| Database | SQLite3 |
| Server | Puma |
| Assets | Propshaft, CSS (no Tailwind, no Bootstrap) |
| Frontend | Turbo (Frames, Streams), Stimulus, Importmap |
| Auth | Devise (admin) |
| Authorization | Pundit |
| Background jobs | Active Job + Solid Queue |
| File storage | Active Storage (local); image_processing for variants |
| Export | Prawn, Prawn-Table, CombinePDF (PDF); caxlsx, caxlsx_rails (Excel) |
| Charts | ApexCharts (insights), Flowbite (donuts), custom CSS |
| Deploy | Kamal, Docker; Thruster optional |

### Prerequisites
- Ruby 3.x  
- Rails 8.1.x  
- SQLite3  
- Bundler  

### Installation
1. `bundle install`
2. `rails db:create && rails db:migrate && rails db:seed`
3. (Optional) Place CSV in `db/Data/` and run `rails data:import`
4. Start server: `rails server` → `http://localhost:3000`

### Background jobs
Export and payment summary emails use Active Job. Run a Solid Queue worker (or equivalent) so export and email jobs run.

### Development
- **Tests:** `rails test`
- **Console:** `rails console`
- **Tasks:** `rails data:import`, `rails attendees:migrate` (if defined)

### License
This project is open source and available for use.
