require_relative '../effect'

module Loomy
  module AST
    module Effects
      class Grayscale < Effect
        def accept(visitor)
          visitor.visit_grayscale_effect(self)
        end
      end
    end
  end
end
