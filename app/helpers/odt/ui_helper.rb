# frozen_string_literal: true

module Odt
  module UiHelper
    # Standard usage (see docs/ui-checklist.md):
    #   odt_page_header(title:, subtitle:, icon:) { actions }
    #   odt_section_header(title:, subtitle:, actions:)
    #   odt_kpi_strip(cells: [...])
    #   odt_card(title:, icon:, header_action: or actions:) { body }
    #   odt_table(extra_class: "...") do ... end

    # Renders ODT Page header. title:, subtitle: (optional), icon: (Bootstrap icon name), extra_class:.
    # Yields optional block for action links (e.g. "New", "Export").
    def odt_page_header(title:, subtitle: nil, icon: nil, extra_class: nil, &block)
      render "components/odt/page_header",
        title: title,
        subtitle: subtitle,
        icon: icon,
        extra_class: extra_class,
        &block
    end

    # Renders ODT Button partial.
    # Options: variant (primary|secondary|ghost|danger|link), size (sm|md|lg),
    # icon_left:, icon_right:, loading:, disabled:, and any HTML options (href, method, data, class, id, etc.)
    def odt_button(label = nil, variant: :primary, size: :md, icon_left: nil, icon_right: nil, loading: false, disabled: false, **options, &block)
      content = block ? capture(&block) : label
      render "components/odt/button",
        label: content,
        variant: variant.to_s,
        size: size.to_s,
        icon_left: icon_left,
        icon_right: icon_right,
        loading: loading,
        disabled: disabled,
        options: options
    end

    # Renders ODT IconButton (32px square).
    # Options: icon (Bootstrap icon name, e.g. "pencil"), variant (primary|secondary|ghost|danger), **options
    def odt_icon_button(icon:, variant: :secondary, **options)
      render "components/odt/icon_button", icon: icon.to_s, variant: variant.to_s, options: options
    end

    # Renders ODT Card. Header: title + optional icon + optional action.
    # Options: title, icon (Bootstrap icon name), header_action or actions (HTML/captured content for header right),
    #          header (raw HTML if title not set), footer, hoverable, extra_class
    def odt_card(hoverable: false, extra_class: nil, title: nil, icon: nil, header_action: nil, actions: nil, **options, &block)
      content = block ? capture(&block) : nil
      render "components/odt/card",
        body: content,
        hoverable: hoverable,
        extra_class: extra_class,
        title: title,
        icon: icon,
        header_action: header_action || actions,
        options: options
    end

    # Renders ODT AccentCard (left border 4px). accent: :info|:warning|:danger|:success
    def odt_accent_card(accent: :info, **options, &block)
      content = block ? capture(&block) : nil
      render "components/odt/accent_card", accent: accent.to_s, body: content, options: options
    end

    # Renders ODT MetricCard (KPI). title:, value:, icon:, accent: (primary|success|info|accent), subtext: optional
    def odt_metric_card(title:, value:, icon:, accent: :primary, subtext: nil)
      render "components/odt/metric_card",
        title: title,
        value: value,
        icon: icon.to_s,
        accent: accent.to_s,
        subtext: subtext
    end

    # Renders ODT Badge. variant: neutral|info|success|warning|danger|outline. size: sm|md
    # status: paid|pending|overdue|receipt (pill style, status colors)
    def odt_badge(text, variant: :neutral, size: :md, status: nil)
      render "components/odt/badge", text: text, variant: (variant || :neutral).to_s, size: size.to_s, status: status&.to_s
    end

    # Renders ODT DataTable (shared table system). Yields for thead+tbody, or tbody only when columns: provided.
    # Options: extra_class:, sticky_header: (boolean), columns: (array of { label:, width: :xs|:sm|:md|:lg|:xl, align: :left|:right|:center, truncate: boolean, class: "..." }).
    # Row highlight: add class "odt-tr--selected" or "odt-tr--active" on <tr>. Name cell: .cell-stack with .cell-stack__primary / .cell-stack__secondary.
    def odt_table(extra_class: nil, sticky_header: false, columns: nil, table_id: nil, **options, &block)
      content = block ? capture(&block) : nil
      render "components/odt/table",
        content: content,
        extra_class: extra_class,
        sticky_header: sticky_header,
        columns: columns,
        table_id: table_id,
        options: options
    end

    # Renders ODT Grid Table (div-based, CSS Grid). Columns fit content or flex; table never exceeds container width.
    # columns: [{ key:, label:, type: "text"|"stack"|"num"|"badge"|"actions"|"html", width: "fit"|"sm"|"md"|"lg"|"xl" }]
    # rows: array of hashes (keys match column key; stack uses key_secondary/key_meta, badge uses key_badge_class)
    # row_actions: array of HTML strings (same length as rows) for the actions column.
    def odt_grid_table(columns:, rows:, row_actions: [], extra_class: nil)
      render "components/odt/grid_table",
        columns: columns,
        rows: rows,
        row_actions: row_actions,
        extra_class: extra_class
    end

    # Renders ODT Table empty state. message (string), icon (optional Bootstrap icon name)
    def odt_table_empty_state(message = "No data", icon: "inbox")
      render "components/odt/table_empty_state", message: message, icon: icon.to_s
    end

    # Renders ODT TableActionMenu (dropdown). items: array of { label:, icon:, url: or path, method: :get|:delete, data: {} }
    def odt_action_menu(items:, button_title: "More")
      render "components/odt/action_menu", items: items, button_title: button_title
    end

    # Renders ODT AmountCell. amount (number or string), incl_vat: "incl. VAT", tooltip: optional
    def odt_amount_cell(amount, incl_vat: "incl. VAT", tooltip: nil)
      render "components/odt/amount_cell", amount: amount, incl_vat: incl_vat, tooltip: tooltip
    end

    # Renders ODT KPI Strip. cells: array of { icon:, label:, value:, sub:, value_variant: (optional, e.g. "danger") }
    def odt_kpi_strip(cells:, extra_class: nil)
      render "components/odt/kpi_strip", cells: cells, extra_class: extra_class
    end

    # Renders ODT SectionHeader. title:, subtitle: (optional), actions: (optional HTML string)
    def odt_section_header(title:, subtitle: nil, actions: nil, extra_class: nil)
      render "components/odt/section_header", title: title, subtitle: subtitle, actions: actions, extra_class: extra_class
    end

    # Renders ODT Metric. label:, value:, meta: (optional)
    def odt_metric(label:, value:, meta: nil, extra_class: nil)
      render "components/odt/metric", label: label, value: value, meta: meta, extra_class: extra_class
    end

    # Renders ODT DocChip. text:, variant: (warning|info|default), url: (optional), turbo_frame: (optional)
    def odt_doc_chip(text, variant: :default, url: nil, turbo_frame: nil, extra_class: nil)
      render "components/odt/doc_chip", text: text, variant: variant.to_s, url: url, turbo_frame: turbo_frame, extra_class: extra_class
    end

    # Renders ODT Filters row wrapper. form_url:, form_method: (:get), form_options: (e.g. data: { turbo_frame: "..." }), extra_class:.
    # Yields content for the row (filter fields + actions).
    def odt_filters_row(form_url:, form_method: :get, form_options: {}, extra_class: nil, &block)
      render "components/odt/filters_row",
        form_url: form_url,
        form_method: form_method,
        form_options: form_options,
        extra_class: extra_class,
        &block
    end
  end
end
