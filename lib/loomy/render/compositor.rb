# frozen_string_literal: true

module Loomy
  module Render
    # Flattens a set of placed images onto a transparent background.
    #
    # Everything goes through a single libvips `composite` call taking arrays of
    # images, blend modes and coordinates, rather than one composite per layer.
    class Compositor
      Placed = Data.define(:image, :blend, :x, :y)

      # `premultiplied` is passed whether or not it is set: false is what
      # libvips assumes anyway, and the option belongs to `composite` itself, so
      # any build that can run this method at all accepts it.
      def self.render(placed, width, height, premultiplied: false)
        background = transparent(width, height)
        return background if placed.empty?

        background.composite(
          placed.map(&:image),
          placed.map(&:blend),
          x: placed.map(&:x),
          y: placed.map(&:y),
          premultiplied: premultiplied
        )
      end

      # Fully transparent black, which is the one image `premultiplied` cannot
      # be wrong about: (0, 0, 0, 0) is the fixed point of premultiply and
      # unpremultiply alike, so the background reads the same under either
      # claim and this needs no variant.
      def self.transparent(width, height)
        Vips::Image.black(width, height, bands: 3).copy(interpretation: :srgb).bandjoin(0)
      end
    end
  end
end
