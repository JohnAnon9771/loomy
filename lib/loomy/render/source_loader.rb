# frozen_string_literal: true

module Loomy
  module Render
    # Produces the pixels of a source at the exact size layout settled on,
    # described by a Target, and caches them for the duration of one render.
    #
    # Measuring is not here: it lives in the SourceCache this composes, which
    # answers `bounds_of` before a render exists at all.
    class SourceLoader
      # libvips needs a number for the axis the caller did not constrain. This
      # doubles as a ceiling: a source taller than this on the free axis gets
      # scaled down to fit it.
      NO_LIMIT = 10_000

      SIZING = { contain: :both, cover: :both, stretch: :force }.freeze

      # Loaders that can decode straight to a reduced size. For everything else
      # `thumbnail(path, ...)` decodes in full anyway and then costs ~2x more
      # than decoding and resizing by hand (measured on PNG and TIFF), so the
      # choice is worth making per format. Both paths are pixel-identical.
      SHRINK_ON_LOAD = %w[jpegload webpload heifload jxlload pdfload svgload].freeze

      def initialize(sources)
        @sources = sources
        @images = {}
      end

      def load(path, target = Target.natural)
        @images[[path, target]] ||= read(path, target)
      end

      # The image cropped to the extent of its content and then scaled to the
      # target. Trimming needs a full-resolution pixel scan either way, so
      # cropping first and resizing after costs nothing extra and is exact.
      #
      # The crop is unconditional: a source with nothing to trim reports its own
      # full extent, so the Trimmer already decided what "no content" means and
      # this does not get a second opinion on it.
      def load_trimmed(path, target = Target.natural, mode = :auto)
        @images[[path, :trimmed, mode, target]] ||= begin
          left, top, width, height = @sources.trim_bounds(path, mode)

          resize(read(path, Target.natural).crop(left, top, width, height), target)
        end
      end

      # An effect map scaled to cover the image it modulates.
      #
      # Not `load`: a map's bands are read positionally -- the first drives x
      # and the second drives y -- so the alpha band `load` adds to an opaque
      # source would be read as displacement data.
      def load_map(path, target)
        @images[[path, :map, target]] ||= resize(@sources.oriented(path), target)
      end

      private

      def read(path, target)
        image = @sources.oriented(path)
        return with_alpha(image) unless target.resize?(image)

        if shrink_on_load?(path)
          Vips::Image.thumbnail(path.to_s, target.width || NO_LIMIT, **thumbnail_options(target))
        else
          image.thumbnail_image(target.width || NO_LIMIT, **thumbnail_options(target))
        end
      end

      def resize(image, target)
        return image unless target.resize?(image)

        image.thumbnail_image(target.width || NO_LIMIT, **thumbnail_options(target))
      end

      def thumbnail_options(target)
        options = { height: target.height || NO_LIMIT, size: SIZING.fetch(target.fit, :both) }
        options[:crop] = :centre if target.fit == :cover

        options
      end

      def shrink_on_load?(path) = SHRINK_ON_LOAD.include?(@sources.loader_name(path))

      def with_alpha(image)
        image.has_alpha? ? image : image.bandjoin(255)
      end
    end
  end
end
