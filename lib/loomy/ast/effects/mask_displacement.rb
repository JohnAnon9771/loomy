# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class MaskDisplacement < Effect
        def scale
          properties[:scale] || 20
        end

        def mask_path
          properties[:mask_path] || properties[:from_mask]
        end

        def intensity
          properties[:intensity] || 1.0
        end

        def accept(visitor)
          visitor.visit_mask_displacement_effect(self)
        end
      end
    end
  end
end
