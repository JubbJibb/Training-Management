# Class Finance Dashboard – Notes

## Design guide & style

Use this guide to keep the Finance tab consistent with the ODT design system and the Payment Status / Timeline card patterns.

### Colors

| Token / variable | Hex / value | Usage |
|------------------|-------------|--------|
| `--odt-dark` / `--color-ink` | `#292929` | Primary text, headings |
| `--odt-blue` / `--color-primary` | `#13139c` | Primary actions, links, accent bar, positive emphasis |
| `--odt-accent` / `--color-accent` | `#ffc700` | Highlight, “Total” row, Corporate segment |
| `--odt-soft` | `#f5bf00` | Accent hover / secondary |
| `--odt-bg` / `--color-surface` | `#f9f9fe` | Page background |
| `--odt-blue-tint` | `rgba(19,19,156,0.06)` | Card header background, hover states |
| `--odt-muted` | `#6b7280` | Secondary labels, captions |
| `--color-success` | `#059669` | Paid, profit ≥ 0, positive metrics |
| `--color-warning` / amber | `#f59e0b` | Pending, caution |
| `--color-danger` | `#dc2626` | Overdue, loss, negative metrics |
| Table header | `#eef2f8` | Sticky table thead |
| Border light | `#e5e7eb` | Dividers, card borders |

### Typography

- **Font**: `var(--font-family)` (Inter fallback to system).
- **Scale**: Use `--font-size-*` from `design_tokens.css`:
  - `--font-size-sm` (12px): labels, table headers.
  - `--font-size-base` (14px): body, table cells.
  - `--font-size-md` (15px): subtitles.
  - `--font-size-lg` (16px): section titles, card titles.
  - `--font-size-2xl` / `--font-size-3xl`: page/section headings.
- **Weight**: 500 labels, 600 subheadings, 700 headings and main numbers.

### Spacing patterns

- **Section gap**: `24px` between major blocks (KPI row, two-col, cash section, main+sidebar).
- **Card internal**: `16px 20px` body padding (`.class-finance-card__body`).
- **Card header**: `12px 16px`; left accent bar `3px` solid `--odt-blue`.
- **Spacing scale**: `--space-1` (4px) through `--space-6` (32px) for consistent padding/margins.

### Card pattern (Payment Status / Timeline style)

- **Container**: `.class-finance-card` — white background, `border-radius: 8px`, light border, subtle shadow.
- **Header**: `.class-finance-card__header` — background `--odt-blue-tint`, **left border `3px solid var(--odt-blue)`**, bold title.
- **Title**: `.class-finance-card__title` — `1rem`, `font-weight: 700`, `#292929`.
- **Body**: `.class-finance-card__body` — padding as above.
- Use this pattern for: main dashboard container, P&L Breakdown, Revenue Composition & Discounts, and any new finance blocks.

### Timeline / list pattern (P&L ladder)

- **List**: `.class-finance-pl-timeline` — left border `2px solid var(--odt-blue)`, `padding-left: 20px`.
- **Item**: `.class-finance-pl-timeline__item` — vertical rhythm, `padding-bottom: 12px`.
- **Dot**: `.class-finance-pl-timeline__dot` — 12px circle; modifiers:
  - `--primary`: blue (revenue steps).
  - `--total`: accent yellow (total row).
  - `--success`: green (profit ≥ 0).
  - `--danger`: red (loss).
  - `--neutral`: grey (costs, neutral steps).
- **Content row**: `.class-finance-pl-timeline__content` — flex space-between for label + value.
- **Divider**: `.class-finance-pl-timeline__divider` — dashed line between revenue and costs.

### Status & metrics

- **KPI / metric tones**: `cfo-metric-strip__value--success` (green), `--warning` (amber), `--danger` (red), `--primary` (blue), `--default` (dark).
- **Badges**: `odt-badge` with variants `:success`, `:warning`, `:danger`, `:primary`, `:neutral` for Paid / Pending / Overdue and Segment.
- **Amounts**: Right-align; use `number_to_thb` for display. Negative amounts: prefix “−” and optionally use danger tone for loss.

### Responsive

- **1440px**: Full layout; KPI row 6 columns; two-col side-by-side; sidebar right.
- **1024px**: KPI 3 columns; two-col stacks; main+sidebar stacks.
- **768px**: KPI 2 columns; Payment Intelligence strip 2 columns; tables horizontal scroll with sticky header and first column.

### Methods / usage summary

- **Cards**: Wrap any new finance section in `.class-finance-card` with `.class-finance-card__header` (blue bar) + `.class-finance-card__body`.
- **Numbers**: Prefer `number_to_thb` / `number_to_percent` in views; in query objects use `format('%.1f', x)` etc. for strings.
- **Tables**: Use `.class-finance-payment-table` (or `.odt-table`) with `.class-finance-table-wrap`; keep dates `.class-finance-payment-table__date` with `white-space: nowrap`, amount column `min-width: 140px`.
- **Empty states**: Use `.cfo-empty`; keep copy short (e.g. “Add more payments and expenses to see insights.”).

---

## Data model mapping (query → view)

- **kpis**: gross_sales, net_revenue_before_vat, cash_received, outstanding, collection_rate_pct, net_profit, profit_margin_pct
- **waterfall**: gross_sales, discount_total, net_before_vat, vat_amount, total_incl_vat, discount_rate_pct, avg_revenue_per_seat, avg_discount_per_seat
- **profitability**: total_cost, profit, gross_margin_pct, cost_per_seat, profit_per_seat
- **payment_status_list**: each row has contact, email, segment, amount, due_date, payment_date, status (Paid/Pending/Overdue), **days_to_pay** (integer, only when paid), attendee
- **segment_split**: indi/corp each with amount, count, seats
- **promotions_performance**: promotion_name, seats_used, discount_cost, revenue, avg_per_seat, margin_impact_pct, chips (Most Used, Highest Revenue, Most Costly)
- **payment_intelligence**: collection_rate_pct, avg_days_to_pay, pct_paid_under_7_days, pct_late
- **insights**: array of up to 5 strings (computed from metrics above)

## Backend / optional fields

- **Date range filter (date_from, date_to)**: UI present in header; controller and `ClassFinanceDashboardQuery` do not yet filter by date. To support: pass `date_from`, `date_to` from params into the query and scope attendees (e.g. by `due_date` or `created_at`).
- **Days to pay**: computed as `paid_date - due_date` (integer). When `due_date` is missing we do not compute; consider using invoice date if added to the schema.
- **Margin vs last class**: insight “Margin improved by +X% vs last class” is not implemented; would require a comparable previous class (e.g. same course or date range) and is optional/mock.
- **Cost categories**: P&L uses `cost_by_category` from the query (Base cost + class_expenses by category). Schema has `class_expenses.category` (string); map to “Instructor”, “Venue”, “Material”, “Marketing”, “Other” in admin when creating expenses if you want consistent labels.

## Safe mocks

- If `segment_split` or `promotions_performance` is empty, views show empty state / zero amounts.
- If no payments have both `due_date` and `payment_date`, `avg_days_to_pay` and `pct_paid_under_7_days` are nil and displayed as “—”.
- Insights array can be empty; the insights partial shows “Add more payments and expenses to see insights.”

## Table UX (Payment Status List)

- Sticky header and sticky first column (Customer) via `.class-finance-payment-table` and `.class-finance-payment-table__customer`.
- Dates: `white-space: nowrap` on `.class-finance-payment-table__date`.
- Amount column: `min-width: 140px`.
- Customer name truncates with ellipsis; full name + email in `title` for tooltip.
- Sorting: not implemented in frontend; can be added via Stimulus or server-side (sort param) on Amount, Due Date, Days to Pay.
