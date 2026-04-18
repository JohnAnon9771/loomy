# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Displacement < Effect
        def scale
          properties[:scale] || 20
        end

        def intensity
          properties[:intensity] || 1.0
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
          visitor.visit_displacement_effect(self)
        end
      end
    end
  end
end
