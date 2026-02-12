# frozen_string_literal: true

module Odt
  module UiHelper
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

    # Renders ODT Card. Header can be structured (title + optional icon + optional action) or raw (header:).
    # Options: title (string), icon (Bootstrap icon name), header_action (HTML string or captured content),
    #          header (raw HTML, used when title not set), footer (HTML), hoverable, extra_class
    def odt_card(hoverable: false, extra_class: nil, title: nil, icon: nil, header_action: nil, **options, &block)
      content = block ? capture(&block) : nil
      render "components/odt/card",
        body: content,
        hoverable: hoverable,
        extra_class: extra_class,
        title: title,
        icon: icon,
        header_action: header_action,
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

    # Renders ODT DataTable wrapper. Yields for thead/tbody.
    # Use with: <%= odt_table do %><thead>...</thead><tbody>...</tbody><% end %>
    # Add class "odt-table-numeric" to th/td for right-aligned numeric columns.
    def odt_table(extra_class: nil, **options, &block)
      content = block ? capture(&block) : nil
      render "components/odt/table", content: content, extra_class: extra_class, options: options
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
  end
end
