# frozen_string_literal: true

module Exports
  # Uses db/Data/Template.pdf as cover/first page(s) for PDF reports when the file exists.
  module PdfTemplateHelper
    TEMPLATE_PATH = Rails.root.join("db", "Data", "Template.pdf").freeze

    class << self
      # @param content_io [IO, StringIO] PDF content from Prawn
      # @return [StringIO] Template pages + content pages, or content only if no template
      def wrap_with_template(content_io)
        return content_io unless template_exists?

        require "combine_pdf"
        template_pdf = CombinePDF.load(TEMPLATE_PATH.to_s)
        content_io.rewind
        report_pdf = CombinePDF.parse(content_io.read)
        combined = template_pdf << report_pdf
        out = StringIO.new
        out.write(combined.to_pdf)
        out.rewind
        out
      end

      def template_exists?
        TEMPLATE_PATH.file? && TEMPLATE_PATH.readable?
      end
    end
  end
end
