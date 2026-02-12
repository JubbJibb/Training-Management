# frozen_string_literal: true

module Exports
  # Registers a Thai-capable font with Prawn when a TTF is present, so COMPANY header (Thai) renders.
  # Add e.g. Sarabun-Regular.ttf to app/assets/fonts/ for full Thai support; otherwise ASCII fallback is used.
  module PrawnFontHelper
    FONT_DIRS = [
      -> { Rails.root.join("app/assets/fonts") },
      -> { Rails.root.join("vendor/fonts") },
      # System paths that may contain a Thai-capable font (e.g. Sarabun, Thonburi)
      -> { Pathname.new("/Library/Fonts") },
      -> { Pathname.new("/System/Library/Fonts/Supplemental") }
    ].freeze

    # ASCII fallback when no Thai-capable font is available (avoids Prawn "text not compatible with font" error)
    COMPANY_ASCII = {
      name: "Odd-E (Thailand) Co., Ltd.",
      address: "2549/41-43 Phahonyothin, Lat Yao, Chatuchak, Bangkok 10900",
      email: "th@odd-e.com",
      phone: "020110684",
      tax_id: "0-1055-56110-71-8"
    }.freeze

    class << self
      def thai_font_path
        @thai_font_path ||= find_thai_font
      end

      def apply_font(pdf)
        if thai_font_path
          pdf.font_families.update("Thai" => { normal: thai_font_path, bold: thai_font_path })
          pdf.font "Thai"
        else
          pdf.font "Helvetica"
        end
      end

      def company_for_prawn
        thai_font_path ? BaseExport::COMPANY : COMPANY_ASCII
      end

      private

      def find_thai_font
        # Prefer known Thai-capable font names, then any TTF
        preferred = %w[Sarabun Thonburi Ayuthaya AngsanaUPC]
        FONT_DIRS.each do |dir_proc|
          dir = dir_proc.call
          next unless dir.respond_to?(:directory?) && dir.directory?
          preferred.each do |name|
            path = Dir.glob(dir.join("#{name}*.ttf")).first
            return path.to_s if path
          end
          path = Dir.glob(dir.join("*.ttf")).first
          return path.to_s if path
        end
        nil
      end
    end
  end
end
