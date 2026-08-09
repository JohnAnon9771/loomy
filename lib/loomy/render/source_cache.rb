# frozen_string_literal: true

module Loomy
  module Render
    # What can be known about a source without producing pixels at a particular
    # size: how it is oriented, how big it is, where its opaque content sits.
    #
    # Separate from SourceLoader because the two are wanted at different times.
    # A loader belongs to a render: it holds images at the sizes layout settled
    # on, so it cannot exist before layout does. Measurements are wanted
    # earlier -- `bounds_of` asks for a trim while the DSL block is still being
    # evaluated -- so they live here, in an object that owns no render.
    #
    # It also owns the access mode, because that is a property of the open
    # handle and this is what opens it.
    class SourceCache
      # EXIF orientation 1 means "already upright".
      UPRIGHT = 1

      # Whether a source that opened has to decode all the way through -- a
      # separate question from whether its header parsed, and one libvips answers
      # "no" to by default. Off, a PNG that stops half-way opens, measures and
      # composites without a word, and the missing half reaches the output as
      # whatever the decoder had in its buffer; the same truncation in a JPEG is
      # refused, so off also means the answer depends on the format.
      #
      # :truncated rather than :error or :warning, which would also reject the
      # images phone encoders emit cosmetic complaints about and decode perfectly.
      # Costs nothing measurable, on either open or a full pixel scan.
      FAIL_ON = :truncated

      def initialize
        @oriented = {}
        @trims = {}
        @streamable = Set.new
      end

      # Declares sources that will be read once, top to bottom, and so can be
      # streamed instead of decoded whole.
      #
      # Opt-in, because getting it wrong is a hard error rather than a slow
      # render: anything not named here keeps random access. Already-open
      # sources are dropped, since a handle cannot change mode after the fact.
      def allow_streaming(paths)
        @streamable.merge(paths - @oriented.keys)
      end

      # Natural size. libvips is lazy, so reading it decodes no pixels.
      def dimensions(path)
        image = oriented(path)
        [image.width, image.height]
      end

      # Content extent of the image, as [left, top, width, height]. Needs a
      # pixel scan, so the result is cached -- per mode as well as per path,
      # since the same source can be asked both ways in one composition and the
      # two modes are two different scans with two different answers.
      def trim_bounds(path, mode = :auto)
        @trims[[path, mode]] ||= decoding(path) { Trimmer.bounds(oriented(path), mode) }
      end

      # Which libvips loader handles this file, or nil if it will not say.
      # Whether that loader can decode straight to a reduced size is the
      # caller's policy, not this one's.
      #
      # Asked of the metadata rather than rescued from reading it. Every image
      # that came from a file carries the field, so an absent one means a
      # generated image and not a source that failed. The rescue this replaces
      # wrapped the whole method, `oriented` included, so an unopenable file came
      # back as "no loader" and the real failure surfaced later, somewhere with
      # no path left in scope.
      def loader_name(path)
        image = oriented(path)

        image.get_typeof('vips-loader').zero? ? nil : image.get('vips-loader')
      end

      # The source with any EXIF orientation tag already applied.
      #
      # Applied once, up front, so that measuring and rendering agree on how big
      # the source is. libvips' thumbnail applies it on its own, so measuring the
      # unrotated header while rendering rotated pixels left layout holding a
      # frame the image did not fill -- a camera JPEG asked for 50x25 measured
      # 50x25 and rendered 13x25.
      #
      # autorot strips the tag once applied, so a later thumbnail cannot rotate a
      # second time. It is skipped outright for upright sources: it is a real
      # pipeline stage even when it has nothing to do, and almost every image is
      # upright.
      def oriented(path)
        @oriented[path] ||= decoding(path) do
          raise SourceNotFound, path unless File.readable?(path.to_s)

          image = Vips::Image.new_from_file(path.to_s, access: access_for(path), fail_on: FAIL_ON)
          orientation(image) == UPRIGHT ? image : image.autorot
        end
      end

      # The first source whose pixels will not decode, or nil if they all will.
      # For the write to ask once it has already failed, since a truncated source
      # and a bad output format arrive there as the same exception.
      #
      # Fresh handles, not the ones already open: a :sequential source the failed
      # render has already read cannot be read again, so reusing them would report
      # a perfectly good file as broken.
      def undecodable_path
        @oriented.keys.find do |path|
          # avg reads every pixel, which is the whole question being asked.
          Vips::Image.new_from_file(path.to_s, access: :sequential, fail_on: FAIL_ON).avg
          false
        rescue Vips::Error
          true
        end
      end

      private

      # libvips says what went wrong but never which file it was reading, and a
      # composition with a dozen sources needs the name for the answer to be
      # worth anything.
      def decoding(path)
        yield
      rescue Vips::Error => e
        raise InvalidSource.new(path, e.message)
      end

      # :sequential streams the source and holds a window of it; :random decodes
      # it whole. Random is the default: it is what a caller holding the image
      # can read as many times as it likes.
      def access_for(path) = @streamable.include?(path) ? :sequential : :random

      def orientation(image)
        image.get_typeof('orientation').zero? ? UPRIGHT : image.get('orientation')
      end
    end
  end
end
