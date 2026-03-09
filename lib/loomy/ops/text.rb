require_relative "base"

module Loomy
  module Ops
    class Text < Base
      attr_reader :text, :font, :size, :color, :width

      def initialize(text:, font: "sans", size: 12, color: "#000", width: nil)
        super(input: nil)
        @text  = text
        @font  = font
        @size  = size
        @color = color
        @width = width
      end

      def call(context = nil)
        mask = Vips::Image.text(text, font: "#{font} #{size}", width: width || 0)
        rgba = Solid.new(color: color, width: mask.width, height: mask.height).call(context)
        rgba.extract_band(0, n: 3).bandjoin(mask)
      end
    end
  end
end
