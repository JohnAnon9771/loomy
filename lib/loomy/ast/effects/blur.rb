# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Blur < Effect
        def radius
          properties[:radius] || 0
        end

        def accept(visitor)
          visitor.visit_blur_effect(self)
        end
      end
    end
  end
end
