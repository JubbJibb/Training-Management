# Budget Management – Integration notes

## Routes

- `GET /budget` → redirects to current year overview (or years list if none)
- `GET /budget/years` → list years, create new
- `GET /budget/years/:id` → year overview (KPIs, spend by category, monthly trend)
- `GET /budget/years/:id/allocations` → allocations table, inline create/update per category
- `GET /budget/years/:id/expenses` → expense register (filters + table, Turbo frame)
- `GET /budget/years/:id/monthly` → monthly summary (month selector, KPIs, by category, expense list)
- `GET/POST /budget/expenses/new`, `GET/PATCH /budget/expenses/:id/edit`, `PATCH /budget/expenses/:id/mark_paid`
- `GET /budget/events` → events list; new/create/edit/update
- `GET /budget/events/:id` → event details + sponsorship deals
- `GET /budget/sponsorship_deals/:id` → deal details + linked expenses, “Add expense” link

## First-time setup

1. Run migrations: `bin/rails db:migrate`
2. Run seeds: `bin/rails db:seed` (creates default budget categories)
3. Create a budget year: go to `/budget/years` → “New budget year” (set year, total budget, status e.g. active)
4. Set allocations: open the year → Allocations → set “Allocated amount” per category and Add/Update

## Design

- Uses existing ODT layout (admin), `insight-card`, `odt-table`, `odt-kpi-strip`, `odt-filters-row`, design tokens (--odt-accent, etc.)
- Badges: planned=stone, committed=amber, paid=emerald, over=rose (see `.budget-badge--*` in years/index)
- No Tailwind; CSS uses application.css and inline `<style>` in partials where needed

## Optional enhancements

- **Sponsorship deals CRUD**: Currently events have show/edit; deals are shown on event show. To create deals, add `resources :sponsorship_deals, only: [:new, :create, :edit, :update]` under events or at top level and forms with `event_id`.
- **Export**: Monthly page has a disabled “Export” button placeholder; hook up to a CSV/Excel export using `Budget::Summary.by_category_for_month` and expense list.
- **Forecast EOY**: Year overview KPI “Forecast EOY” is currently same as total spend; can replace with an extrapolation (e.g. average monthly × remaining months).
- **Auth**: All budget controllers use `Budget::BaseController` with `layout "admin"`; ensure admin auth (e.g. Devise) is required for these routes if needed.

## Stimulus

- `budget-filter`: form submit on change (select/input); optional `data-budget-filter-debounce-value="300"` for text input.
- `budget-month-switch`: submit form on month select change to refresh monthly summary Turbo frame.

## SQLite

- `monthly_plan` on allocations uses `json` (not `jsonb`) for SQLite compatibility.
