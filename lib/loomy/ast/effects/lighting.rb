# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Lighting < Effect
        # How the map is read as light. Which libvips blend each one composites
        # with is a pixel decision, so that mapping lives with the processor.
        TYPES = %i[soft hard].freeze
        DEFAULT_TYPE = :soft

        def type     = properties[:type] || DEFAULT_TYPE
        def strength = properties[:strength] || 1.0
        def map      = properties[:map]

        # Strength scales the map towards mid-grey, which both blends leave
        # alone, so only zero is a no-op. A negative strength inverts the light
        # -- highlight becomes shadow -- which is a picture, not an absence.
        def no_op? = strength.zero?
      end
    end
  end
end
