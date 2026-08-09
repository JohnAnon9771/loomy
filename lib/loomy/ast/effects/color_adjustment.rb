# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class ColorAdjustment < Effect
        NEUTRAL = 1.0

        def brightness = properties[:brightness] || NEUTRAL
        def contrast   = properties[:contrast] || NEUTRAL

        def no_op? = neutral?(brightness) && neutral?(contrast)

        private

        def neutral?(value) = (value - NEUTRAL).abs < Float::EPSILON
      end
    end
  end
end
