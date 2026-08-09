# frozen_string_literal: true

module Loomy
  module Render
    module Sources
      # A flat rectangle of one colour.
      class Solid
        def initialize(color, width, height)
          @color = Color.new(color)
          @width = width
          @height = height
        end

        def call
          Vips::Image
            .black(@width, @height, bands: 3)
            .linear(1, @color.to_rgb)
            .copy(interpretation: :srgb)
            .bandjoin(@color.a)
        end
      end
    end
  end
end
