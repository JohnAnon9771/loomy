# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class ColorAdjustment < Effect
        NEUTRAL = 1.0

        def brightness = properties[:brightness] || NEUTRAL
        def contrast   = properties[:contrast] || NEUTRAL

        # Both have to be neutral, and that is exact rather than conservative:
        # the processor's gain is contrast * brightness and its offset is zero
        # only when contrast is 1, which in turn leaves brightness as the whole
        # gain. There is no other pair that lands on the identity.
        def no_op? = neutral?(brightness) && neutral?(contrast)

        private

        def neutral?(value) = (value - NEUTRAL).abs < Float::EPSILON
      end
    end
  end
end
