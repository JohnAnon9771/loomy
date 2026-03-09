module Loomy
  module AST
    module Effects
      class Displacement < Effect
        def scale
          properties[:scale] || 20
        end

        def accept(visitor)
          visitor.visit_displacement_effect(self)
        end
      end
    end
  end
end
