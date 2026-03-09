module Loomy
  module Ops
    class Solid < Base
      attr_reader :color, :width, :height

      def initialize(color:, width: 1, height: 1)
        super(input: nil)
        @color  = Color.new(color)
        @width  = width
        @height = height
      end

      def call(_context = nil)
        Vips::Image
          .black(width, height, bands: 3)
          .linear(1, @color.to_rgb)
          .copy(interpretation: :srgb)
          .bandjoin(@color.a)
      end
    end
  end
end
