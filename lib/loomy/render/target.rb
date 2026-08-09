# frozen_string_literal: true

module Loomy
  module Render
    # What layout decided a source has to become: the exact pixel size, and how
    # to get there.
    #
    #   :contain  scale to fit inside it, preserving aspect ratio (default)
    #   :cover    scale to fill it and crop the overflow
    #   :stretch  scale each axis independently to hit it exactly
    #
    # Layout has already worked out which of these produces the frame it
    # recorded, so the loader only has to carry it out.
    Target = Data.define(:width, :height, :fit) do
      # The source at its own size, unmodified.
      def self.natural = new(width: nil, height: nil, fit: :contain)

      def sized? = !(width.nil? && height.nil?)

      # False when the image already is what was asked for, so the resample can
      # be skipped. Layout resolves a size for every layer, including ones that
      # render at their natural size, so this is the common case.
      def resize?(image)
        return false unless sized?

        (width && width != image.width) || (height && height != image.height)
      end
    end
  end
end
