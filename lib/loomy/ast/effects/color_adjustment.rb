# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class ColorAdjustment < Effect
        def brightness
          properties[:brightness] || 1.0
        end

        def contrast
          properties[:contrast] || 1.0
        end

        def accept(visitor)
          visitor.visit_color_adjustment_effect(self)
        end
      end
    end
  end
end
