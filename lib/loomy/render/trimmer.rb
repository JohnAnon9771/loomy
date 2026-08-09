# frozen_string_literal: true

module Loomy
  module Render
    # Where an image's content actually is, as [left, top, width, height].
    #
    # Two modes, because "border" means two different things and neither answer
    # is the other's approximation:
    #
    #   :alpha  the extent of the pixels that are not fully transparent. Colour
    #           plays no part, so nothing about the colourspace can change the
    #           answer.
    #   :color  the extent of the pixels that differ from a background colour,
    #           which is what libvips' find_trim measures. The only mode that
    #           can trim artwork carrying no alpha channel at all.
    #   :auto   whichever of the two the source can answer, decided by whether
    #           it has an alpha channel. The default, and what a `trim: true`
    #           layer means -- writing it out says the same as leaving it off.
    #
    # The split exists because find_trim's background defaults to *white*. A
    # white subject on a transparent background is indistinguishable from that
    # background once flattened against it, so the whole image reads as border
    # and the scan comes back empty -- a source that asked to be trimmed and
    # silently was not. Greyscale and CMYK sources miss for the same reason.
    # Trimming by alpha has no constant that can be wrong.
    #
    # Where the two disagree, beyond that:
    #
    #   - :alpha is exact. Any pixel above zero alpha is content, down to a
    #     single one. find_trim median-filters first, so it loses a 1px feature
    #     outright, and it discounts a faint halo that :alpha keeps.
    #   - :alpha is also cheaper: ~17ms against find_trim's ~113ms on a
    #     4200x4800 source, and the measure pass pays that once per source.
    class Trimmer
      # The vocabulary `trim:` and `bounds_of` accept, and the subset of it that
      # is a scan of its own. :auto is a mode to ask for, never one to run.
      SCANS = %i[alpha color].freeze
      MODES = [:auto, *SCANS].freeze

      # How far a pixel has to sit from the background colour to count as
      # content. Only :color has a threshold; :alpha needs no tolerance because
      # it is not comparing against a colour it had to guess.
      COLOUR_THRESHOLD = 10

      # => [left, top, width, height], with width and height always positive.
      #
      # An image with nothing to find -- fully transparent, or entirely the
      # background colour -- reports its own full extent rather than an empty
      # box. Callers measure and crop from this, and there is no smaller answer
      # that means anything; returning the degenerate box would only push the
      # same fallback out to each of them.
      def self.bounds(image, mode = :auto)
        left, top, width, height = extent(image, resolve(mode, image))
        return [0, 0, image.width, image.height] unless width.positive? && height.positive?

        [left, top, width, height]
      end

      # The mode a scan actually runs in. Everything that is not a scan of its
      # own -- :auto, and the `true` a `trim:` layer arrives carrying -- defers
      # to the source, which is the question the caller was really asking.
      def self.resolve(mode, image)
        return mode if SCANS.include?(mode)

        image.has_alpha? ? :alpha : :color
      end

      def self.extent(image, mode)
        mode == :alpha ? alpha_extent(image) : image.find_trim(threshold: COLOUR_THRESHOLD)
      end

      # profile reports, for every column, how far down the first non-zero pixel
      # sits, and for every row how far in from the left. Rotating the band by
      # half a turn asks the same two questions of the opposite edges, so two
      # scans answer for all four.
      #
      # A source with no alpha has no transparent border to find, and nothing to
      # trim. Not "trim it by colour instead": that is a different request, and
      # it has its own mode.
      def self.alpha_extent(image)
        return [0, 0, image.width, image.height] unless image.has_alpha?

        alpha = image.extract_band(image.bands - 1)
        columns, rows = alpha.profile
        turned_columns, turned_rows = alpha.rot180.profile

        left, width = span(rows, turned_rows, image.width)
        top, height = span(columns, turned_columns, image.height)

        [left, top, width, height]
      end

      # Where the content starts on one axis and how far it runs, from the two
      # profiles measuring that axis from opposite ends.
      #
      # A band that is zero throughout reports the full length everywhere, so
      # the two edges cross, the span comes back negative and `bounds` falls
      # back. min answers with a Float, and these go on to be crop arguments and
      # frame sizes, so it does not stay one.
      def self.span(near, far, length)
        start = near.min.to_i

        [start, length - far.min.to_i - start]
      end
    end
  end
end
