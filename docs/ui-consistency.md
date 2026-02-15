# Admin UI consistency spec

Reference: **Admin Dashboard** (`app/views/admin/dashboard/index.html.erb`) and **Financial Dashboard KPI strip**. Use design tokens from `design_tokens.css` and `application.css` (`:root`). Do **not** introduce Bootstrap or Tailwind.

---

## 1. Typography scale

| Use case | Token | Approx | Notes |
|----------|--------|--------|--------|
| Page title (h1) | `--font-size-3xl` | 1.5rem (24px) | `.odt-page-header__title` |
| Section title (h2) | `--font-size-lg` to `--font-size-xl` | 1rem–1.125rem | `.odt-section-header__title` |
| Card title | `--font-size-lg` | 1rem | `.odt-card__header-title` |
| Body, table cells | `--font-size-base` | 0.875rem (14px) | Body text, `td` |
| Labels, table headers | `--font-size-sm` | 0.75rem (12px) | Uppercase labels in KPI; `th` |
| Captions, meta | `--font-size-xs` | 0.6875rem (11px) | `.odt-kpi-strip__label`, `.odt-kpi-strip__sub` |
| Subtitle | `--font-size-md` | 0.9375rem (15px) | `.odt-page-header__subtitle` |

- **Font family**: `var(--font-family)` (Inter fallback) everywhere.
- **Weights**: 400 body, 500 labels, 600 values/headers, 700 titles.
- **Forbidden**: Arbitrary `font-size` (e.g. `1.2rem`, `0.9rem`) without a token; mixing rem and px inconsistently.

---

## 2. Spacing scale

| Use case | Token | Notes |
|----------|--------|--------|
| Page outer padding | `--space-3` to `--space-5` | e.g. `.admin-layout-main` |
| Section margin bottom | `--space-4` or `--space-5` | Between major sections |
| Card body padding | `--space-5` | `.odt-card__body` |
| Card header padding | `--space-4` `--space-5` | `.odt-card__header` |
| Table cell padding | ~0.875rem 1rem | `thead th`, `tbody td` (consistent across tables) |
| KPI cell padding | `--space-2` | `.odt-kpi-strip__cell` |
| Filters row gap | `--space-3` | Between filter fields and buttons |
| Inline gaps (e.g. header actions) | `--space-2` | Between buttons/links |

- **Forbidden**: Magic numbers (e.g. `padding: 13px`) instead of `--space-*`.

---

## 3. Border radius, border, shadow

| Element | Radius | Border | Shadow |
|---------|--------|--------|--------|
| Page / container | — | — | None |
| Card | `var(--radius-md)` (12px) | `1px solid rgba(41,41,41,0.06)` or `var(--border-light)` | `var(--shadow-sm)` |
| KPI strip | `var(--radius-sm)` (8px) | `var(--border-light)` | **None** |
| Section header (standalone) | `var(--radius-sm)` (8px) | `border-left: 4px solid var(--odt-blue)` | None |
| Filters row | `var(--radius-sm)` | `var(--border-light)` | `0 1px 3px rgba(0,0,0,0.05)` (subtle) |
| Table wrapper | Often inside card; no extra radius | — | — |
| Buttons | `var(--radius-xs)` (6px) | Per variant | None (or very subtle) |

- **Forbidden**: Shadows on KPI strip; heavy shadows on cards; random left accent borders outside section headers.

---

## 4. Standard layouts

### 4.1 Page header (`.odt-page-header`)

- One row: **text block** (icon + title + optional subtitle) + **actions** (links/buttons).
- Icon: Bootstrap Icons `bi bi-*`, color `var(--odt-blue)`.
- Title: `--font-size-3xl`, bold, `var(--color-ink)`.
- Subtitle: `--font-size-md`, `var(--odt-muted)`.
- Actions: flex wrap, gap `--space-2`.
- Margin bottom: `--space-5`.

### 4.2 Section header (`.odt-section-header`)

- Optional **left accent**: 4px solid `var(--odt-blue)` only when used as standalone bar (e.g. section container header).
- Background: light grey (e.g. `#f0f3f7` or token if defined), padding `1rem 1.25rem`, flex title + actions.
- Title: bold, ~1rem–1.2rem.
- Subtitle: muted, smaller.
- **Forbidden**: Left accent on every card; mixing with card header style.

### 4.3 KPI strip (`.odt-kpi-strip`)

- **Single strip**: one row, equal-width columns, no cards per cell.
- **Background**: Tinted only, e.g. `var(--odt-blue-tint)`.
- **No shadow**, **no left accent** on the strip or on cells.
- **Structure per cell**: icon (optional) + **uppercase label** (`--font-size-xs`, muted) → **big value** (large, bold, right-aligned) → **muted meta** (sub, `--font-size-xs`, right-aligned).
- Dividers: vertical `var(--border-light)` between columns; last column no border.
- Grid: e.g. 6 columns default; responsive 3 → 2 columns via media queries. Page-specific wrappers (e.g. `.dashboard-kpi-strip`) may override column count.

### 4.4 Card (`.odt-card`)

- Container: white bg, radius `--radius-md`, border light, shadow sm.
- Optional header: title + optional icon + optional action; border-bottom.
- Body: padding `--space-5`.
- Optional footer: border-top, same padding scale.
- **Forbidden**: Left accent on card unless it’s an explicit “accent card” variant (e.g. `.odt-accent-card`).

### 4.5 Table (`.odt-table`, `.odt-table-wrap`)

- Wrapper: `.odt-table-wrap` (overflow, no card by itself unless inside card).
- Table: `.odt-table`; thead th: `--table-th-font-size`, uppercase/labels, background e.g. `#eef2f8` or token.
- First th: optional 4px left border `var(--odt-blue)` only when table is **not** inside a section that already has a section header with accent.
- Cell padding: consistent (e.g. 0.875rem 1rem).
- Numeric columns: `.odt-table-numeric`, right-aligned.

### 4.6 Filters row (`.odt-filters-row`)

- One row: form with **fields** (label + input/select) + **actions** (Apply, Clear).
- Labels: `--font-size-sm`, muted.
- Inputs: consistent height (e.g. 34px), `--radius-xs`, `var(--border-light)`.
- Sticky optional; background white; subtle border and light shadow.
- **Forbidden**: Inconsistent input heights or label font sizes across admin pages.

---

## 5. Forbidden

- **Shadows on KPI strip** (strip must stay flat, tinted only).
- **Random left accent borders** (only section header or explicit accent card).
- **Inconsistent font sizes** (use typography scale and tokens).
- **Bootstrap/Tailwind** (keep plain CSS + tokens).
- **Per-cell cards in KPI** (KPI is one strip, not a grid of cards).
- **Heavy shadows** on cards (use `--shadow-sm` only).
- **Magic numbers** for spacing/radius (use `--space-*`, `--radius-*`).
- **Hardcoded colors** (use `--color-ink`, `--odt-blue`, `--odt-muted`, `--border-light`, etc.).

---

## 6. Components (ERB partials)

| Component | Path | Usage |
|-----------|------|--------|
| Page header | `components/odt/_page_header.html.erb` | Title, subtitle, optional icon, optional actions block |
| Section header | `components/odt/_section_header.html.erb` | Title, optional subtitle, optional actions |
| KPI strip | `components/odt/_kpi_strip.html.erb` | `odt_kpi_strip(cells:, extra_class:)`; cells: icon, label, value, sub, value_variant, trend |
| Card | `components/odt/_card.html.erb` | `odt_card(title:, icon:, ...) { body }` |
| Table | `components/odt/_table.html.erb` | `odt_table(extra_class:) { thead + tbody }` |
| Filters row | `components/odt/_filters_row.html.erb` | `odt_filters_row(form_url:, form_method: :get, form_options: {}, &block)` or `render "components/odt/filters_row", form_url: ..., &block`. Inner structure: `.odt-filters-row__row` with `.odt-filters-row__field` (label + input) and `.odt-filters-row__actions` (buttons: `.odt-filters-row__btn--primary`, `.odt-filters-row__btn--secondary`). |

CSS classes for these: `.odt-page-header`, `.odt-section-header`, `.odt-kpi-strip`, `.odt-card`, `.odt-table` (with `.odt-table-wrap`), `.odt-filters-row`.
