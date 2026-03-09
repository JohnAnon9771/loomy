require_relative "base"

module Loomy
  module Ops
    class Solid < Base
      attr_reader :color, :width, :height

      def initialize(color:, width: 1, height: 1)
        super(input: nil)
        @color  = color
        @width  = width
        @height = height
      end

      def call(_context = nil)
        r, g, b, a = rgba
        
        Vips::Image.black(width, height, bands: 3)
                   .linear(1, [r, g, b])
                   .copy(interpretation: :srgb)
                   .bandjoin(a)
      end

      private

      def rgba
        case color
        when String then hex_to_rgba(color)
        when Array  then color_from_array(color)
        else [0, 0, 0, 255]
        end
      end

      def color_from_array(array)
        array.length == 3 ? array + [255] : array
      end

      def hex_to_rgba(hex)
        hex = hex.delete("#")
        parts = case hex.length
                when 3 then hex.chars.map { |c| c * 2 }
                when 6, 8 then hex.scan(/../)
                else return [0, 0, 0, 255]
                end
        
        rgba = parts.map { |p| p.hex }
        rgba << 255 if rgba.length == 3
        rgba
      end
    end
  end
end
