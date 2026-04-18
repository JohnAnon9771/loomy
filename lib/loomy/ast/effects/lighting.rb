# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Lighting < Effect
        def type
          properties[:type] || :soft_light
        end

        def strength
          properties[:strength] || 1.0
        end

        def from_mask
          properties[:from_mask]
        end

        def from_mask?
          !properties[:from_mask].nil?
        end

        def map_path
          properties[:map]
        end

        def accept(visitor)
          visitor.visit_lighting_effect(self)
        end
      end
    end
  end
end
