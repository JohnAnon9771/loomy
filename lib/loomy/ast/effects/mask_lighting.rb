# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class MaskLighting < Effect
        def mask_path
          properties[:mask_path] || properties[:from_mask]
        end

        def strength
          properties[:strength] || 1.0
        end

        def type
          properties[:type] || :soft_light
        end

        def accept(visitor)
          visitor.visit_mask_lighting_effect(self)
        end
      end
    end
  end
end
