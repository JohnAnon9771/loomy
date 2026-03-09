module Loomy
  module Ops
    class Gradient < Base
      attr_reader :from, :to, :direction, :width, :height

      def initialize(from:, to:, direction: :top_bottom, width: 1, height: 1)
        super(input: nil)
        @from      = Color.new(from)
        @to        = Color.new(to)
        @direction = direction
        @width     = width
        @height    = height
      end

      def call(_context = nil)
        diff  = @to.rgba.zip(@from.rgba).map { |t, f| t - f }
        base  = Vips::Image.black(width, height, bands: 3).linear(1, @from.to_rgb)
        mask  = render_mask
        res   = (base + mask.bandjoin([mask, mask]) * diff[0..2]).copy(interpretation: :srgb)
        alpha = mask * diff[3] + @from.a
        
        res.bandjoin(alpha)
      end

      private

      def render_mask
        xyz = Vips::Image.xyz(width, height)
        
        case direction
        when :top_bottom then xyz.extract_band(1) / height.to_f
        when :left_right then xyz.extract_band(0) / width.to_f
        else xyz.extract_band(1) / height.to_f
        end
      end
    end
  end
end
