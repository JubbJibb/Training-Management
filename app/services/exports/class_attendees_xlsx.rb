# frozen_string_literal: true

module Exports
  class ClassAttendeesXlsx < BaseExport
    def suggested_filename
      "class-attendees-#{Date.current.iso8601}.xlsx"
    end

    def build_io
      require "caxlsx"
      range = date_range
      scope = Attendee.attendees.joins(:training_class).where("training_classes.date >= ? AND training_classes.date <= ?", range.begin, range.end)
      scope = scope.where(training_class_id: filters[:course_id]) if filters[:course_id].present?
      scope = scope.where(participant_type: filters[:segment]) if filters[:segment].present?
      scope = scope.includes(:training_class).order("training_classes.date DESC, attendees.name")

      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Attendees") do |sheet|
        sheet.add_row %w[Class_Date Class_Title Name Email Phone Company Type Seats Channel Payment Document_Status], style: sheet.workbook.styles.add_style(b: true)
        scope.find_each do |a|
          tc = a.training_class
          sheet.add_row [tc.date, tc.title, a.name, a.email, a.phone.to_s, a.company.to_s, a.participant_type, a.seats, a.source_channel.to_s, a.payment_status.to_s, a.document_status.to_s]
        end
        sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen_split; pane.y_split = 1 }
      end
      io = p.to_stream
      io.rewind
      io
    end
  end
end
