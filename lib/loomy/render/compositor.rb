# frozen_string_literal: true

module Loomy
  module Render
    # Flattens a set of placed images onto a transparent background.
    #
    # This is the part of the old engine worth keeping: everything goes through
    # a single libvips `composite` call with arrays of images, blend modes and
    # coordinates, rather than one composite per layer.
    class Compositor
      Placed = Data.define(:image, :blend, :x, :y)

      def self.render(placed, width, height)
        background = transparent(width, height)
        return background if placed.empty?

        background.composite(
          placed.map(&:image),
          placed.map(&:blend),
          x: placed.map(&:x),
          y: placed.map(&:y)
        )
      end

      def self.transparent(width, height)
        Vips::Image.black(width, height, bands: 3).copy(interpretation: :srgb).bandjoin(0)
      end
    end
  end
end
