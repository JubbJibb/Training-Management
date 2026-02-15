# Navigation – Executive Information Architecture

## Summary of changes

- **Top-level menu:** Insights | Operations | Clients | Financials | Strategy | Settings
- **Exports** removed from top nav. Export History is under **Financials** → Export History (`/finance/export_jobs`).
- **Contextual exports** remain on:
  - Training class show: Export CSV, Export to Excel (Documents tab)
  - Customer show: Export dropdown (Customer Info, Billing for Accounting, template)
  - Finance dashboard: Export Report (PDF), Export Excel (quick actions)

## Route map

| Path | Controller#action | Notes |
|------|-------------------|--------|
| `/insights` | admin/insights#index | → redirects to Admin Dashboard |
| `/insights/financial` | admin/insights#financial | → redirects to /finance |
| `/insights/strategy` | admin/insights#strategy | → redirects to Promotions (admin/settings) |
| `/insights/actions` | admin/insights#actions | → redirects to Admin Dashboard #action-required |
| `/training_classes` | redirect | → /admin/training_classes |
| `/courses` | redirect | → /admin/courses |
| `/instructors` | admin/instructors#index | Lists instructors from training classes |
| `/customers` | redirect | → /admin/customers |
| `/companies` | redirect | → /admin/customers?segment=Corp |
| `/finance` | finance_dashboards#index | Financial Overview (CFO dashboard) |
| `/finance/ar` | admin/finance#index | Accounts Receivable |
| `/finance/payments` | admin/finance#index | Payment Tracking (same controller) |
| `/finance/expenses` | admin/expenses#index | Expense Control |
| `/finance/compliance` | admin/compliance#index | Compliance placeholder |
| `/finance/export_jobs` | admin/exports#index | Export History (audit) |
| `/finance_dashboard` | redirect | → /finance (backward compatibility) |
| `/promotions` | redirect | → /admin/settings |
| `/promotions/performance` | redirect | → /admin/settings#performance |
| Admin namespace | unchanged | dashboard, training_classes, courses, customers, exports, settings, etc. |

## Menu copy / tooltips

- **Insights:** Consolidated performance & decision support
- **Operations:** Manage program delivery and enrollment
- **Clients:** 360° client portfolio and history
- **Financials:** Revenue, receivables, expenses, compliance
- **Strategy:** Campaigns, promotions and growth optimization
- **Settings:** Promotion & system settings

## Files changed

| File | Change |
|------|--------|
| `config/routes.rb` | Executive IA routes (insights, finance/*, redirects); removed duplicate `finance_dashboard` direct route (kept redirect only) |
| `app/views/layouts/admin.html.erb` | Uses `shared/main_nav` (already present) |
| `app/views/shared/_main_nav.html.erb` | Dropdowns: Insights, Operations, Clients, Financials, Strategy; Export History under Financials; added Opportunities; added `nav-dropdown__toggle` for active styling |
| `app/helpers/application_helper.rb` | `nav_active?` for insights, operations, clients, financials, strategy, settings |
| `app/controllers/admin/insights_controller.rb` | Redirects to dashboard/finance/settings (already present) |
| `app/controllers/admin/instructors_controller.rb` | Index of instructors (already present) |
| `app/controllers/admin/expenses_controller.rb` | Expense Control index (already present) |
| `app/controllers/admin/compliance_controller.rb` | Compliance placeholder (already present) |
| `docs/NAVIGATION_IA.md` | This summary and checklist |

## Manual test checklist

- [ ] **Nav structure:** Top bar shows Insights | Operations | Clients | Financials | Strategy | Settings. No “Exports” at top level.
- [ ] **Insights dropdown:** Business Insights → Admin Dashboard; Financial Insights → /finance; Strategy Insights → Promotions; Action Center → Admin Dashboard.
- [ ] **Operations dropdown:** Training Classes → list; Courses → list; Instructors → instructor list.
- [ ] **Clients dropdown:** Client Directory → customers; Corporate Accounts → customers with segment=Corp.
- [ ] **Financials dropdown:** Financial Overview → /finance; AR → admin finance; Payment Tracking → same; Expense Control → expenses index; Compliance → compliance placeholder; Export History → exports index (audit).
- [ ] **Strategy dropdown:** Promotions → settings; Promotion Performance → settings; Opportunities → Admin Dashboard.
- [ ] **Settings:** Goes to admin/settings (Promotion).
- [ ] **Backward compatibility:** Visiting `/finance_dashboard` redirects to `/finance`.
- [ ] **Contextual exports:** Training class (Export CSV, Documents tab export); Customer (Export dropdown); Finance dashboard (Export Report / Export Excel).
- [ ] **Export History:** Reachable via Financials → Export History; page shows export jobs and creation flows as before.
