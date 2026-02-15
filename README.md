# ODT Training Management System

Internal Training Management System for managing public and corporate training classes, attendees, customers, promotions, finance, and exports. Built with **Ruby on Rails** and **Turbo** for a modern, responsive admin experience. Replaces spreadsheet-based workflows with a unified web UI, design system, and background export jobs.

---

## Table of Contents

- [Business Features](#business-features)
- [Technical Design](#technical-design)
- [Design Principles](#design-principles)
- [Design System](#design-system)
- [Project Structure](#project-structure)
- [Knowledge & Documentation](#knowledge--documentation)
- [Setup & Development](#setup--development)

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
- **Admin Auth** — Session-based (`session[:admin_user_id]`); bcrypt; Pundit for authorization (e.g. ExportJob).

---

## Technical Design

### High-level architecture
- **Controllers** — Thin: params/filters in controller, load data for view. Export creates `ExportJob` and enqueues `GenerateExportJob`.
- **Services** — Business logic and side effects: `CustomerSyncService`, `Exports::*` (PDF/Excel), `PromotionPerformanceQuery`, `Promotions::MetricsService`, `Customers::DirectoryQuery`, `Clients::CorporateAccountsInsights`, `Insights::*` (business, financial, strategy, action center), `Finance::FinanceDashboardSummary`, `FinancialOverviewService`.
- **Jobs** — `GenerateExportJob` (reads export_type/format, calls matching export service, attaches file to ExportJob, updates state). `SendPaymentSummaryJob` for payment summary emails.
- **Policies** — Pundit (e.g. `ExportJobPolicy`). `current_user` from session; no role column on admin_users (role-based UI deferred).
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

---

## Design System

**ODT** (brand) theme: consulting-premium, enterprise SaaS look. No Tailwind; no Bootstrap. All UI via `design_tokens.css`, `design_system.css`, and `application.css`.

### Tokens (`design_tokens.css` + `application.css` :root)
- **Font** — `--font-family`: Inter + system fallbacks.
- **Typography** — `--font-size-xs` (11px) through `--font-size-4xl` (28px).
- **Colors** — `--color-ink` (#292929), `--color-primary` (#13139c), `--color-accent` (#ffc700), `--color-surface` (#f9f9fe); `--odt-blue`, `--odt-gold`, `--odt-soft`, `--odt-muted`; semantic success/warning/danger.
- **ODT palette** — Primary Navy #13139c, Deep Navy #012a71, Yellow Accent #ffc700, Soft Yellow #f5bf00, Dark Text #292929, Light BG #f9f9fe; hover tints (e.g. rgba(1,42,113,0.05)).
- **Spacing** — `--space-1` (4px) to `--space-6` (32px); `--odt-spacing`, `--odt-section`.
- **Radii & shadows** — `--radius-xs/sm/md`, `--shadow-sm/md`, `--border-light`.

### Components (`design_system.css` + `application.css` + `components/odt/`)
- **Page / section** — Page header, section header (title + optional actions); left accent bar (4px primary) for emphasis.
- **Cards** — `.card`, `.card--accent-left`; ODT card with optional icon and header action.
- **Buttons** — `.btn`, `.btn--primary`, `.btn--secondary`, `.btn--danger`, `.btn--ghost`, `.btn--sm`; icon buttons.
- **KPI / metrics** — KPI strip (grid of metric cells); single metric cards.
- **Tables** — ODT table (fixed layout, column classes, numeric/actions cells, truncate).
- **Filters** — Filters row (label + input groups, Apply/Clear).
- **Badges** — Status and label badges.
- **Empty states** — Shared empty state partial.
- **Calendar** — Training Calendar uses `cal-*` classes: header with accent and yellow underline, day headers (navy + yellow bottom border), day cells (no overflow), event cards (white, left accent, progress bar, FULL badge), side panel, KPIs, legend.

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
| Assets | Propshaft, CSS (no Tailwind) |
| Frontend | Turbo (Frames, Streams), Stimulus, Importmap |
| Auth | Session (admin_user_id), bcrypt |
| Authorization | Pundit |
| Background jobs | Active Job + Solid Queue |
| File storage | Active Storage (local); image_processing for variants |
| Export | Prawn (PDF), caxlsx (Excel) |
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
