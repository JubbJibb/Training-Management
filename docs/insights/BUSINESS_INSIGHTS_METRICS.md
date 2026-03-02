# Business Insights – Metric Definitions & API Shape

## Metric formulas

| Metric | Definition | Edge cases |
|--------|------------|------------|
| **leads** | Count of attendee records in scope (status = attendee). No separate Lead model; "lead" = registration. | Exclude refunded/cancelled if we add status. |
| **paid** | Count of attendees with `payment_status = "Paid"`. | One row = one registration; multi-seat counts as 1 order. |
| **attended** | Count of attendees with `attendance_status = "มาเรียน"`. | If no tracking: show 0 and empty-state message. |
| **revenue** | Sum of `total_final_price` for paid attendees only. Already includes seats (price × seats after discount). | Exclude refunded; no refund flag in schema = use paid only. |
| **avg_price_per_head** | `revenue / paid_count` (THB per paid order). | If paid_count = 0 → 0 or N/A. |
| **cvr** | `paid / leads` (or registered) × 100. Lead→Paid conversion. | leads = 0 → 0%. |
| **repeat_rate** | % of unique customers (customer_id) in scope who have ≥2 paid attendee records (lifetime or in range, configurable). | No customer_id → exclude from denominator. |
| **returning_revenue_pct** | Revenue from customers with ≥2 paid classes / total revenue × 100. | If no repeat customers → 0%. |
| **gross_margin** | Sum(class revenue − class cost − class_expenses) for classes in range. Revenue = paid attendees' total_final_price per class. | If cost data missing → N/A with tooltip. |
| **previous_period** | Same-length window immediately before start_date. E.g. range 1–30 Jun → previous = 2–31 May. | Compare to previous period toggle (default ON). |

## Refunds / duplicates / multi-seat

- **Refunds**: Schema has no refund flag; revenue = sum of paid only. If refunds added later, exclude refunded amount from revenue and exclude from paid count.
- **Duplicates**: One email per training_class_id (unique); no double-count.
- **Multi-seat**: `total_final_price` = (unit price after discount) × seats; one row = one order. Paid count = number of rows with Paid, not sum of seats (for CVR consistency). Revenue uses total_final_price (includes seats).

## API response shape (JSON)

```json
{
  "date_range": { "start_date": "2026-01-01", "end_date": "2026-01-31", "preset": "mtd" },
  "compare_to_previous_period": true,
  "previous_period": { "start_date": "2025-12-01", "end_date": "2025-12-31" },
  "executive_summary": { "text": "30 วันที่ผ่านมา: รายได้ ฿499,255 · ใบชำระ 42 · CVR 85% · Repeat 12%" },
  "kpis": [
    { "key": "revenue", "label": "Revenue (THB)", "value": 499255.36, "delta": 0.12, "delta_label": "+12%", "sparkline": [10, 20, 15, 40, ...] },
    { "key": "paid_orders", "label": "Paid orders", "value": 42, "delta": -0.05, "delta_label": "-5%", "sparkline": [...] },
    { "key": "avg_price_per_head", "label": "Avg price/head (THB)", "value": 11887, "delta": 0.08, "delta_label": "+8%", "sparkline": [...] },
    { "key": "cvr", "label": "CVR Lead→Paid (%)", "value": 85.0, "delta": 2.0, "delta_label": "+2pp", "sparkline": [...] },
    { "key": "repeat_rate", "label": "Repeat rate (%)", "value": 12.0, "delta": 0.5, "delta_label": "+0.5pp", "sparkline": [...] },
    { "key": "gross_margin", "label": "Gross margin", "value_thb": 474177, "value_pct": 95.0, "delta": null, "delta_label": null, "sparkline": [], "na_reason": null }
  ],
  "trend": {
    "granularity": "daily",
    "revenue_trend": [{ "date": "2026-01-01", "label": "01/01", "revenue": 12000, "registered": 5, "paid": 4, "attended": 3 }],
    "orders_trend": "same as revenue_trend with registered/paid/attended"
  },
  "best_selling_courses": {
    "by_revenue": [{ "course": "Fundamentals of...", "revenue": 192600, "paid": 1, "avg_price_head": 192600, "cvr": 100, "sparkline": [] }],
    "by_paid": [...],
    "by_cvr": [...]
  },
  "pricing_insights": {
    "avg_price_trend": [{ "date": "...", "label": "...", "avg_price_per_head": 12000 }],
    "distribution": [{ "bucket": "<10k", "count": 5 }, { "bucket": "10–20k", "count": 20 }, { "bucket": "20–30k", "count": 10 }, { "bucket": ">30k", "count": 7 }]
  },
  "channel_mix": [{ "label": "06/01", "Online": 3, "Offline": 2, "อื่นๆ": 1 }],
  "channel_performance": {
    "sort_by": "revenue",
    "rows": [{ "channel": "Online", "leads": 50, "paid": 42, "revenue": 400000, "avg_price_head": 9524, "cvr": 84.0 }]
  },
  "cohort_heatmap_data": { "row_labels": [...], "col_labels": ["เดือน+1", "เดือน+2", "เดือน+3"], "cells": [[...]] },
  "returning_revenue_pct": 18.5,
  "summary": { "period_label": "...", "registered": 50, "paid": 42, "attended": 38, "conversion_pct": 76, "top_channel": "...", "top_course": "...", "repeat_pct": 12 },
  "funnel_data": [{ "label": "ลงทะเบียน", "value": 50 }, ...],
  "top_channels": [...],
  "top_courses": [...],
  "top_spenders": [...],
  "repeat_learners": [...]
}
```
