# frozen_string_literal: true

module Loomy
  module Render
    module Sources
      # A two-stop linear gradient, interpolated in RGBA so the alpha channel
      # ramps too.
      class Gradient
        DIRECTIONS = %i[top_bottom left_right].freeze

        def initialize(spec, width, height)
          @from = Color.new(spec[:from])
          @to = Color.new(spec[:to])
          @direction = spec[:direction] || :top_bottom
          @width = width
          @height = height
        end

        def call
          delta = @to.rgba.zip(@from.rgba).map { |to, from| to - from }
          base = Vips::Image.black(@width, @height, bands: 3).linear(1, @from.to_rgb)
          ramp = mask

          rgb = (base + (ramp.bandjoin([ramp, ramp]) * delta[0..2])).copy(interpretation: :srgb)
          rgb.bandjoin((ramp * delta[3]) + @from.a)
        end

        private

        # 0..1 along the gradient's axis.
        def mask
          xyz = Vips::Image.xyz(@width, @height)

          case @direction
          when :left_right then xyz.extract_band(0) / @width.to_f
          else xyz.extract_band(1) / @height.to_f
          end
        end
      end
    end
  end
end
