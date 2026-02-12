# frozen_string_literal: true

module Customers
  # Builds a customer directory relation with computed aggregates (times_attended,
  # last_attended_at, total_spent_net, outstanding_amount). Supports segment filters
  # (all, indi, corp, top_spenders) and search. Uses SQL aggregation to avoid N+1.
  #
  # total_spent_net_raw: sum of Amount (total_amount) for Paid attendees only = Total Spend.
  # outstanding_raw: sum of Amount for Pending attendees.
  # total_amount on attendee = same as Amount shown in UI (total_final_price), kept in sync by callback.
  # TODO: top_percent option for Top Spenders (e.g. top 10% by spend).
  # TODO: Add tests for segment filters, top_n limit, and search; watch performance with large datasets.
  class DirectoryQuery
    SEGMENTS = %w[all indi corp top_spenders].freeze
    DEFAULT_TOP_N = 20

    def initialize(params = {})
      @q = params[:q].to_s.strip.presence
      @segment = params[:segment].to_s.presence || "all"
      @segment = "all" unless SEGMENTS.include?(@segment)
      @top_n = (params[:top_n].presence || DEFAULT_TOP_N).to_i
      @top_n = DEFAULT_TOP_N if @top_n < 1
    end

    def call
      rel = base_scope
      rel = apply_search(rel)
      rel = apply_segment(rel)
      rel = apply_sort(rel)
      rel = apply_limit(rel)
      rel
    end

    def segment
      @segment
    end

    private

    def base_scope
      Customer
        .left_joins(attendees: :training_class)
        .group("customers.id")
        .select(
          "customers.*",
          "COUNT(DISTINCT CASE WHEN (attendees.status = 'attendee' OR attendees.status IS NULL OR attendees.status = '') THEN attendees.id END) AS times_attended",
          "MAX(CASE WHEN (attendees.status = 'attendee' OR attendees.status IS NULL OR attendees.status = '') THEN training_classes.date END) AS last_attended_at",
          "COALESCE(SUM(CASE WHEN (attendees.status = 'attendee' OR attendees.status IS NULL OR attendees.status = '') AND attendees.payment_status = 'Paid' THEN COALESCE(attendees.total_amount, attendees.price * attendees.seats) ELSE 0 END), 0) AS total_spent_net_raw",
          "COALESCE(SUM(CASE WHEN (attendees.status = 'attendee' OR attendees.status IS NULL OR attendees.status = '') AND attendees.payment_status = 'Pending' THEN COALESCE(attendees.total_amount, attendees.price * attendees.seats) ELSE 0 END), 0) AS outstanding_raw",
          "COALESCE(SUM(CASE WHEN (attendees.status = 'attendee' OR attendees.status IS NULL OR attendees.status = '') THEN attendees.seats ELSE 0 END), 0) AS seats_total_raw"
        )
    end

    def apply_search(rel)
      return rel if @q.blank?

      like = "%#{@q}%"
      rel = rel.where(
        "customers.name LIKE :q OR customers.email LIKE :q OR customers.phone LIKE :q OR customers.company LIKE :q OR customers.tax_id LIKE :q",
        q: like
      )
      rel
    end

    def apply_segment(rel)
      case @segment
      when "indi"
        rel = rel.where(customers: { participant_type: "Indi" })
      when "corp"
        rel = rel.where(customers: { participant_type: "Corp" })
      when "top_spenders"
        # Subquery: order by total_spent_net desc, take top_n customer ids
        rel = rel.order(Arel.sql("total_spent_net_raw DESC"))
        # Will apply limit in apply_limit; top_spenders uses top_n
      end
      rel
    end

    def apply_sort(rel)
      case @segment
      when "corp", "top_spenders"
        rel.reorder(Arel.sql("total_spent_net_raw DESC"))
      else
        rel.reorder(Arel.sql("COALESCE(last_attended_at, '0001-01-01') DESC"))
      end
    end

    def apply_limit(rel)
      limit = 500
      limit = @top_n if @segment == "top_spenders"
      rel.limit(limit)
    end
  end
end
