# Clients – Corporate Accounts & Client Analysis – Implementation Summary

## Changed / created files

### Migration
- `db/migrate/20260214074415_add_acquisition_channel_to_customers.rb` – add `acquisition_channel` (string, nullable), backfill "unknown"

### Routes
- `config/routes.rb` – scope `clients`: `corporate_accounts` (index), `corporate_accounts/:id` (show), `analysis` (show)

### Controllers
- `app/controllers/clients/base_controller.rb` – layout "admin"
- `app/controllers/clients/corporate_accounts_controller.rb` – index (CorporateAccountsInsights), show (CorporateAccountProfile; redirect if not found)
- `app/controllers/clients/analysis_controller.rb` – show (ClientAnalysis)

### Services
- `app/services/clients/date_range_resolver.rb` – MTD/YTD/Custom
- `app/services/clients/corporate_accounts_insights.rb` – KPIs, accounts table, at-risk list, upcoming unpaid (5 min cache)
- `app/services/clients/corporate_account_profile.rb` – snapshot, AR aging, invoice list, program portfolio, stakeholders, opportunities (5 min cache)
- `app/services/clients/client_analysis.rb` – KPIs, top spenders, concentration, channel, segment mix, risk lists (5 min cache)

### Views
- `app/views/clients/shared/_date_filter.html.erb` – period + start/end + optional yield for extra filters; Turbo Frame `clients_main`
- `app/views/clients/corporate_accounts/index.html.erb` – KPI strip, filters (active, has_overdue, min_revenue), Corporate Accounts table, At Risk panel, Upcoming Unpaid
- `app/views/clients/corporate_accounts/show.html.erb` – Snapshot KPIs, AR aging, invoice list, program portfolio, stakeholders, opportunities
- `app/views/clients/analysis/show.html.erb` – KPI strip, filters (client_type, channel, min_revenue), top spenders chart/table, Pareto table, revenue by channel chart, conversion table, segment donut + mix, risk lists

### Nav
- `app/views/shared/_main_nav.html.erb` – Clients dropdown: Client Directory → admin_customers_path; Corporate Accounts → clients_corporate_accounts_path; Client Analysis → clients_analysis_path
- `app/helpers/application_helper.rb` – `nav_active?("clients")` already includes `path.start_with?("/clients")`

### Tests
- `test/controllers/clients/corporate_accounts_controller_test.rb` – GET index 200; GET show 200 when customer exists, redirect when not found
- `test/controllers/clients/analysis_controller_test.rb` – GET analysis 200
- `test/services/clients/corporate_accounts_insights_test.rb` – call returns expected keys
- `test/services/clients/client_analysis_test.rb` – call returns expected keys

### Docs
- `docs/CLIENTS_DISCOVERY.md` – discovery summary
- `docs/CLIENTS_IMPLEMENTATION.md` – this file

---

## Manual test checklist

### Navigation
- [ ] Clients dropdown shows: Client Directory, Corporate Accounts, Client Analysis
- [ ] Client Directory → `/admin/customers`
- [ ] Corporate Accounts → `/clients/corporate_accounts`
- [ ] Client Analysis → `/clients/analysis`
- [ ] Clients tab is active when on `/clients/*`

### Corporate Accounts index (`/clients/corporate_accounts`)
- [ ] Date filter (MTD/YTD/Custom) + Apply updates content in Turbo Frame
- [ ] Optional filters: Status (Active/Inactive), Overdue (Has overdue), Min revenue
- [ ] KPI strip: Corporate Revenue, Booked Revenue, Outstanding, Overdue, Active Accounts, Avg Payment Days
- [ ] Corporate Accounts table: Company (link to show), Revenue, Outstanding, Overdue, Classes, Last activity, Health badge (Good/Watch/At Risk)
- [ ] At Risk Accounts list (top 10) with link to account show
- [ ] Upcoming Unpaid (Corporate) list with link to attendee

### Corporate Account show (`/clients/corporate_accounts/:id`)
- [ ] Header with account name; link back to All Corporate Accounts
- [ ] Snapshot: Lifetime Revenue, YTD Revenue, Outstanding, Overdue, Repeat rate, Last activity
- [ ] AR Aging table (0-30, 31-60, 60+ days)
- [ ] Invoice list (Ref, Due, Amount, Status)
- [ ] Program portfolio (Program, Classes, Revenue, Profit, Last attended)
- [ ] Stakeholders: Billing contacts, Tax ID, Address
- [ ] Opportunities (e.g. no activity 90 days, upsell)
- [ ] Invalid id redirects to corporate accounts index

### Client Analysis (`/clients/analysis`)
- [ ] Date filter + Client type (All/Corporate/Individual), Channel, Min revenue
- [ ] KPI strip: Total Clients, Active, New, Avg Revenue/Client, Repeat Rate, Corporate % Revenue
- [ ] Top 10 Spenders bar chart and table (Revenue, Profit, Last activity, Type)
- [ ] Revenue concentration (Pareto): Top 10%, 20%, 50%
- [ ] Revenue by Channel bar chart
- [ ] Conversion by Channel table
- [ ] Corporate vs Individual donut
- [ ] Segment mix: One-time vs Repeat, New vs Returning
- [ ] Risk: Outstanding/Overdue list (top 20)
- [ ] Risk: High value no activity 90+ days

### Tests
- [ ] `rails test test/controllers/clients/ test/services/clients/` – all pass

---

## Authorization (future)

- No role column on `admin_users`; all authenticated users can access.
- To add: Corporate Accounts index/show for ops + finance; Client Analysis for ops + strategy/marketing; hide nav items by role; add `before_action` / Pundit in controllers.
