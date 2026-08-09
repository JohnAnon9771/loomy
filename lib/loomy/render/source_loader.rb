# frozen_string_literal: true

module Loomy
  module Render
    # Opens image sources and caches them for the duration of one render.
    #
    # Layout asks it for dimensions and trim bounds while measuring; the
    # renderer then asks for the pixels at the exact size layout settled on.
    class SourceLoader
      # libvips needs a number for the axis the caller did not constrain. This
      # doubles as a ceiling: a source taller than this on the free axis gets
      # scaled down to fit it.
      NO_LIMIT = 10_000

      TRIM_THRESHOLD = 10

      # Loaders that can decode straight to a reduced size. For everything else
      # `thumbnail(path, ...)` decodes in full anyway and then costs ~2x more
      # than decoding and resizing by hand (measured on PNG and TIFF), so the
      # choice is worth making per format. Both paths are pixel-identical.
      SHRINK_ON_LOAD = %w[jpegload webpload heifload jxlload pdfload svgload].freeze

      def initialize
        @headers = {}
        @images = {}
        @trims = {}
      end

      # Natural size, read from the header. libvips is lazy, so this does not
      # decode pixels.
      def dimensions(path)
        image = header(path)
        [image.width, image.height]
      end

      # Opaque extent of the image, as [left, top, width, height]. Needs a pixel
      # scan, so the result is cached per render.
      def trim_bounds(path)
        @trims[path] ||= header(path).find_trim(threshold: TRIM_THRESHOLD)
      end

      # How to reach the requested size:
      #
      #   :contain  scale to fit inside it, preserving aspect ratio (default)
      #   :cover    scale to fill it and crop the overflow
      #   :stretch  scale each axis independently to hit it exactly
      #
      # Layout has already worked out which of these produces the frame it
      # recorded, so the loader only has to carry it out.
      FITS = { contain: :both, cover: :both, stretch: :force }.freeze

      # The image at the requested size. Passing neither width nor height loads
      # it at its natural size.
      def load(path, width: nil, height: nil, fit: :contain)
        @images[[path, width, height, fit]] ||= read(path, width, height, fit)
      end

      # The image cropped to its opaque extent and then scaled to the target.
      # Trimming needs a full-resolution pixel scan either way, so cropping first
      # and resizing after costs nothing extra and is exact.
      def load_trimmed(path, width: nil, height: nil, fit: :contain)
        @images[[path, :trimmed, width, height, fit]] ||= begin
          left, top, trim_width, trim_height = trim_bounds(path)
          image = read(path, nil, nil, fit)
          image = image.crop(left, top, trim_width, trim_height) if trim_width.positive? && trim_height.positive?

          resize(image, width, height, fit)
        end
      end

      private

      def header(path)
        @headers[path] ||= begin
          raise SourceNotFound, path unless File.readable?(path.to_s)

          Vips::Image.new_from_file(path.to_s)
        end
      end

      def read(path, width, height, fit)
        image = header(path)
        # Layout resolves a size for every layer, including ones that render at
        # their natural size, so the common case asks for what is already on
        # disk. Resampling that would be pure waste.
        return with_alpha(image) unless resize?(image, width, height)

        if shrink_on_load?(path)
          Vips::Image.thumbnail(path.to_s, width || NO_LIMIT, **thumbnail_options(height, fit))
        else
          image.thumbnail_image(width || NO_LIMIT, **thumbnail_options(height, fit))
        end
      end

      def resize(image, width, height, fit)
        return image unless resize?(image, width, height)

        image.thumbnail_image(width || NO_LIMIT, **thumbnail_options(height, fit))
      end

      def resize?(image, width, height)
        return false if width.nil? && height.nil?

        (width && width != image.width) || (height && height != image.height)
      end

      def thumbnail_options(height, fit)
        options = { height: height || NO_LIMIT, size: FITS.fetch(fit, :both) }
        options[:crop] = :centre if fit == :cover
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
