# UI style checklist

Use this checklist before merging UI changes to prevent style drift.

## 1. Shared components

- [ ] **Page header:** Use `odt_page_header(title:, subtitle:, icon:) { actions }` (or `render "components/odt/page_header", ...`) — no custom `<h1>` wrappers or page-specific header classes.
- [ ] **Section titles:** Use `render "components/odt/section_header", title:, subtitle:, actions:` or card titles via `odt_card(title:, icon:)` — no one-off `<h2>`/`<h3>` with custom backgrounds or borders.
- [ ] **Cards:** Use `odt_card(title:, icon:, header_action:) { ... }` for all section containers — no raw `.card` or custom card wrappers (e.g. `.class-finance-card__header`).
- [ ] **Filters:** Use `render "components/odt/filters_row", form_url:, form_method:, form_options: { data: { turbo_frame: "..." } }` with block content using `.odt-filters-row__field`, `.odt-filters-row__label`, `.odt-filters-row__input`, `.odt-filters-row__actions`, `.odt-filters-row__btn`.
- [ ] **Tables:** Use `odt_table(extra_class: "...")` with `<thead>`/`<tbody>`; add `.col-xs`–`.col-xl`, `.cell-actions`, `.odt-table-numeric`, `.truncate`, `.cell-stack` as needed. No standalone `<table>` without `.odt-table` and the shared wrapper.
- [ ] **Buttons:** Use `odt_button(...)` or `.odt-btn` classes; avoid raw `.btn` or ad-hoc button markup for primary actions.

## 2. KPIs and metrics

- [ ] **KPI strips:** Use `odt_kpi_strip(cells: [...], extra_class: "dashboard-kpi-strip")` with cells `{ icon:, label:, value:, sub:, value_variant: }`. No page-specific KPI layouts (e.g. custom metric grids or card rows that don’t use the shared strip).
- [ ] **Single metrics:** Use `odt_metric_card` or a single cell in the strip — no new one-off “KPI card” styles per page.

## 3. Tokens and consistency

- [ ] **Colors:** Use design tokens only: `var(--odt-blue)`, `var(--odt-accent)`, `var(--color-ink)`, `var(--color-surface)`, `var(--odt-muted)`, etc. No new hex/rgba for primary UI (except in tokens).
- [ ] **Shadows:** Use `var(--odt-shadow)`, `var(--odt-shadow-hover)`, or existing `var(--shadow-sm)` — no new `box-shadow` values for cards/panels.
- [ ] **Spacing:** Use `var(--space-*)`, `var(--odt-spacing)`, `var(--odt-section)` — no new magic numbers for margins/padding on shared layouts.
- [ ] **Borders/radius:** Use `var(--border-light)`, `var(--radius-sm)`, `var(--radius-md)`, `var(--odt-radius)` — no new border or radius values.

## 4. Tables

- [ ] **All data tables** use the ODT table pattern: `odt_table` wrapper, table has class `.odt-table`, `table-layout: fixed`, column classes (`.col-xs`–`.col-xl`), `.cell-actions` for the actions column, `.odt-table-numeric` for amounts, `.truncate`/`.cell-stack` for text cells.
- [ ] **No** page-only table classes that duplicate layout (e.g. custom thead background or cell padding) — extend via extra_class or existing modifiers only.

## 5. Responsive and layout

- [ ] **Grids:** Use existing layout classes (e.g. `.dashboard-grid`, `.dashboard-grid__left`, `.dashboard-grid__right`, `.odt-finance-two-col`) rather than new ad-hoc flex/grid rules.
- [ ] **Wide tables:** Live inside a scroll container (e.g. `.odt-table-scroll` / `.table-responsive`); no fixed widths that break on small screens.

---

**Quick reference:** Helpers live in `Odt::UiHelper`; components in `app/views/components/odt/`. Global styles and tokens: `app/assets/stylesheets/application.css` (see the style-audit comment at the top).
