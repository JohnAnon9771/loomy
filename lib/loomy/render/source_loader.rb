# frozen_string_literal: true

module Loomy
  module Render
    # Opens image sources and caches them for the duration of one render.
    #
    # Layout asks it for dimensions and trim bounds while measuring; the
    # renderer then asks for the pixels at the exact size layout settled on,
    # described by a Target.
    class SourceLoader
      # libvips needs a number for the axis the caller did not constrain. This
      # doubles as a ceiling: a source taller than this on the free axis gets
      # scaled down to fit it.
      NO_LIMIT = 10_000

      TRIM_THRESHOLD = 10

      # EXIF orientation 1 means "already upright".
      UPRIGHT = 1

      SIZING = { contain: :both, cover: :both, stretch: :force }.freeze

      # Loaders that can decode straight to a reduced size. For everything else
      # `thumbnail(path, ...)` decodes in full anyway and then costs ~2x more
      # than decoding and resizing by hand (measured on PNG and TIFF), so the
      # choice is worth making per format. Both paths are pixel-identical.
      SHRINK_ON_LOAD = %w[jpegload webpload heifload jxlload pdfload svgload].freeze

      def initialize
        @headers = {}
        @oriented = {}
        @images = {}
        @trims = {}
      end

      # Natural size, read from the header. libvips is lazy, so this does not
      # decode pixels.
      def dimensions(path)
        image = oriented(path)
        [image.width, image.height]
      end

      # Opaque extent of the image, as [left, top, width, height]. Needs a pixel
      # scan, so the result is cached per render.
      def trim_bounds(path)
        @trims[path] ||= oriented(path).find_trim(threshold: TRIM_THRESHOLD)
      end

      def load(path, target = Target.natural)
        @images[[path, target]] ||= read(path, target)
      end

      # The image cropped to its opaque extent and then scaled to the target.
      # Trimming needs a full-resolution pixel scan either way, so cropping first
      # and resizing after costs nothing extra and is exact.
      def load_trimmed(path, target = Target.natural)
        @images[[path, :trimmed, target]] ||= begin
          left, top, width, height = trim_bounds(path)
          image = read(path, Target.natural)
          image = image.crop(left, top, width, height) if width.positive? && height.positive?

          resize(image, target)
        end
      end

      # An effect map scaled to cover the image it modulates.
      #
      # Not `load`: a map's bands are read positionally -- the first drives x
      # and the second drives y -- so the alpha band `load` adds to an opaque
      # source would be read as displacement data.
      def load_map(path, target)
        @images[[path, :map, target]] ||= resize(oriented(path), target)
      end

      private

      def header(path)
        @headers[path] ||= begin
          raise SourceNotFound, path unless File.readable?(path.to_s)

          Vips::Image.new_from_file(path.to_s)
        end
      end

      # An EXIF orientation tag is applied once, up front, so that measuring and
      # rendering agree on how big the source is. libvips' thumbnail applies it
      # on its own, so measuring the unrotated header while rendering rotated
      # pixels left layout holding a frame the image did not fill -- a camera
      # JPEG asked for 50x25 measured 50x25 and rendered 13x25.
      #
      # autorot strips the tag once applied, so the thumbnail below cannot
      # rotate a second time. It is skipped outright for upright sources: it is
      # a real pipeline stage even when it has nothing to do, and almost every
      # image is upright.
      def oriented(path)
        @oriented[path] ||= begin
          image = header(path)
          orientation(image) == UPRIGHT ? image : image.autorot
        end
      end

      def orientation(image)
        image.get_typeof('orientation').zero? ? UPRIGHT : image.get('orientation')
      end

      def read(path, target)
        image = oriented(path)
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

      def shrink_on_load?(path)
        SHRINK_ON_LOAD.include?(header(path).get('vips-loader'))
      rescue Vips::Error
        false
      end

      def with_alpha(image)
        image.has_alpha? ? image : image.bandjoin(255)
      end
    end
  end
end
