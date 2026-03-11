# frozen_string_literal: true

module Operations
  module TrainingCalendarHelper
    # Month view: max visible event cards per day before "+N more"
    MAX_VISIBLE_EVENTS_PER_DAY = 3
    # Distance from top of cell to first card (px). Must match CSS --tc-cell-top-offset.
    TC_CELL_TOP_OFFSET = 28
    # Height per span slot (card height + gap). Card 60px + gap 8px = 68.
    TC_SPAN_SLOT_HEIGHT = 68

    # Returns array of week arrays (each week = 7 days). Mon–Sun.
    def tc_week_rows(grid_days)
      grid_days.each_slice(7).to_a
    end

    # Single-day events for a given day: no end_date or end_date == date (excludes multi-day).
    def tc_single_day_events_for_day(events_on_day)
      return [] if events_on_day.blank?
      events_on_day.select { |e| e.end_date.blank? || e.end_date <= e.date }
    end

    # Multi-day events (end_date > date) from events_by_date, unique.
    def tc_multi_day_events(events_by_date)
      events_by_date.values.flatten.uniq.select { |e| e.end_date.present? && e.end_date > e.date }
    end

    # For a multi-day event and a week range, return segment clamped to week: { start_date, end_date, start_col, span_cols }, or nil.
    def tc_week_segment(event, week_start, week_end)
      seg_start = [event.date, week_start].max
      seg_end = [event.end_date || event.date, week_end].min
      span_cols = (seg_end - seg_start).to_i + 1
      return nil if span_cols < 1
      start_col = (seg_start - week_start).to_i + 1
      { start_date: seg_start, end_date: seg_end, start_col: start_col, span_cols: span_cols }
    end

    # Assign vertical slot to each segment so that earlier-starting events are on top; overlapping segments stack. Returns [segments_with_slots, max_slot].
    def tc_span_segments_with_slots(segments_in_week)
      return [[], -1] if segments_in_week.blank?
      sorted = segments_in_week.sort_by { |s| s[:event].date }
      slots = []
      sorted.each_with_index do |seg, i|
        slot = 0
        i.times do |j|
          other = sorted[j]
          next unless tc_segments_overlap?(seg, other)
          slot = [slot, slots[j] + 1].max
        end
        slots << slot
      end
      sorted.each_with_index { |seg, i| seg[:slot] = slots[i] }
      [sorted, slots.max]
    end

    def tc_segments_overlap?(a, b)
      a[:start_col] < b[:start_col] + b[:span_cols] && b[:start_col] < a[:start_col] + a[:span_cols]
    end

    # Sort events for display: start time, then timed > all-day, FULL > ALMOST > other, PRIVATE > PUBLIC, title
    def tc_sort_events(events)
      events.sort_by do |e|
        start_time = e.start_time || Time.current
        is_timed = e.start_time.present? && e.end_time.present?
        fill = (e.fill_rate_percent || 0) / 100.0
        capacity_rank = if e.max_attendees.to_i.positive?
          fill >= 1 ? 0 : (fill >= 0.8 ? 1 : 2)
        else
          2
        end
        private_rank = (e.respond_to?(:class_status) && e.class_status == "private") || (e.respond_to?(:public_enabled?) && !e.public_enabled?) ? 0 : 1
        [
          e.date,
          is_timed ? 0 : 1,
          capacity_rank,
          private_rank,
          start_time,
          e.title.to_s
        ]
      end
    end

    # Returns display label for class status: "Public", "Private", or "Tentative"
    def tc_class_status_label(event)
      return event.class_status.capitalize if event.respond_to?(:class_status) && event.class_status.present?
      event.respond_to?(:public_enabled?) && event.public_enabled? ? "Public" : "Private"
    end

    # Returns true if event has class_status (public/private/tentative) for CSS modifier
    def tc_class_status_modifier(event)
      event.respond_to?(:class_status) && event.class_status.present? ? event.class_status : (event.respond_to?(:public_enabled?) && event.public_enabled? ? "public" : "private")
    end
    def tc_event_time_range(event)
      if event.start_time.present? && event.end_time.present?
        "#{event.start_time.strftime('%H:%M')} - #{event.end_time.strftime('%H:%M')}"
      else
        "All day"
      end
    end

    # Seat status for badge: full, almost, or nil (available)
    def tc_seat_status(event)
      return nil if event.max_attendees.blank? || event.max_attendees.to_i.zero?
      pct = event.fill_rate_percent || 0
      return "full" if pct >= 100
      return "almost" if pct >= 80
      nil
    end

    # Tooltip content for event (full title, times, instructor, location, seats, etc.)
    def tc_event_tooltip(event)
      parts = [event.title]
      if event.start_time.present? && event.end_time.present?
        parts << "#{event.start_time.strftime('%H:%M')}–#{event.end_time.strftime('%H:%M')}"
      else
        parts << "All day"
      end
      parts << event.instructor if event.instructor.present?
      parts << event.location if event.location.present?
      if event.max_attendees.to_i.positive?
        parts << "#{event.total_registered_seats}/#{event.max_attendees} seats"
      end
      parts << tc_class_status_label(event)
      parts.join(" · ")
    end

    # Week view: events that overlap a given hour on a given date (for time-slot grid)
    def tc_events_for_slot(events_on_day, date, hour_start)
      slot_start_min = hour_start * 60
      slot_end_min = (hour_start + 1) * 60
      events_on_day.select do |e|
        next false unless e.date == date
        next false unless e.start_time.present? && e.end_time.present?
        e_start_min = e.start_time.hour * 60 + e.start_time.min
        e_end_min = e.end_time.hour * 60 + e.end_time.min
        e_start_min < slot_end_min && e_end_min > slot_start_min
      end
    end
  end
end
