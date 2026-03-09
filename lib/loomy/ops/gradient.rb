require_relative "base"
require_relative "solid"

module Loomy
  module Ops
    class Gradient < Base
      attr_reader :from, :to, :direction, :width, :height

      def initialize(from:, to:, direction: :top_bottom, width: 1, height: 1)
        super(input: nil)
        @from      = from
        @to        = to
        @direction = direction
        @width     = width
        @height    = height
      end

      def call(_context = nil)
        c_from = Solid.new(color: from).send(:rgba)
        c_to   = Solid.new(color: to).send(:rgba)
        
        diff = c_to.zip(c_from).map { |t, f| t - f }
        
        base = Vips::Image.black(width, height, bands: 3).linear(1, c_from[0..2])
        mask = render_mask
        
        res   = (base + mask.bandjoin([mask, mask]) * diff[0..2]).copy(interpretation: :srgb)
        alpha = mask * (c_to[3] - c_from[3]) + c_from[3]
        
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
