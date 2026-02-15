# Executive Insights – Discovery Summary

## Relevant existing files

### Layout / Nav
- `app/views/layouts/admin.html.erb` – admin layout, yields content
- `app/views/shared/_main_nav.html.erb` – Insights dropdown: Business, Financial, Strategy, Action Center (links to `/insights`, `/insights/financial`, `/insights/strategy`, `/insights/actions`)

### Routes
- `get "insights", to: "admin/insights#index"` (currently redirects)
- `get "insights/financial", to: "admin/insights#financial"` (redirects to /finance)
- `get "insights/strategy", to: "admin/insights#strategy"` (redirects to settings)
- `get "insights/actions", to: "admin/insights#actions"` (redirects to dashboard)

### Controllers
- `app/controllers/admin/insights_controller.rb` – redirects only
- `app/controllers/admin/dashboard_controller.rb` – filters, KPIs, action_required_queue, upcoming_classes, leads_by_channel, repeat/top customers
- `app/controllers/finance_dashboards_controller.rb` – FinancialOverviewService, summary, overview
- `app/controllers/admin/finance_controller.rb` – filtered attendees, revenue/cash/outstanding, corporate billing, action lists

### Models & fields
- **Attendee**: total_amount, payment_status (Pending/Paid), due_date, document_status (QT/INV/Receipt), status (attendee/potential), source_channel, training_class_id, customer_id, seats. Methods: total_final_price, gross_sales_amount, total_price_before_vat. Scopes: attendees, potential_customers, paid.
- **TrainingClass**: title, date, end_date, max_attendees, cost, price. Methods: total_registered_seats, fill_rate_percent, net_revenue, total_cost. Scopes: upcoming, past.
- **Customer**: company, email, name, participant_type.
- **ClassExpense**: amount, category, training_class_id.
- **Promotion**: active, discount_type, discount_value, name. Used via attendee_promotions.
- **ExportJob**: state, requested_by_id, filters, export_type (audit).

No `course_id` on training_classes; “program” = training class (group by title or id).

### Services
- `Finance::FinanceDashboardSummary` – start/end from preset, base_scope (attendees in date range), returns total_incl_vat, cash_received, outstanding, overdue_amount, collection_rate_pct, profit_before_vat, margin_pct, ar_aging_buckets, etc.
- `FinancialOverviewService` – summary, chart_data (monthly), aging_summary, payment_timeline_data.
- `PromotionPerformanceQuery` – kpis, revenue_share (donut), leaderboard_rows, insights, drilldown.

### Charts
- Chart.js used in `app/views/admin/settings/index.html.erb` (donut, line) via CDN script tag.
- Finance dashboard uses inline SVG in `_cashflow_chart.html.erb`.
- No Chartkick. Use Chart.js for Insights (add script in insights layout or parent).

### Authorization
- Pundit in use (e.g. ExportJobPolicy). `current_user` from session[:admin_user_id]. No role column on admin_users; role-based hiding deferred (allow all for now).

### Indexes (schema)
- attendees: customer_id, training_class_id, email+training_class_id unique.
- training_classes: none on date (consider index on date for range queries).
- class_expenses: training_class_id.

## Implementation plan
1. Add `app/services/insights/*.rb` (business, financial, strategy, action_center) returning hashes.
2. Add `namespace :insights` with BusinessController, FinancialController, StrategyController, ActionsController (show).
3. Point `/insights` etc. to new controllers; keep or remove admin/insights redirects.
4. Add shared partials under `app/views/insights/shared/` and date filter.
5. Build four show views using shared components; load Chart.js for chart cards.
6. Request specs for 200; optional service specs for expected keys.
