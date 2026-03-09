module Loomy
  module AST
    module Effects
      class Lighting < Effect
        def type
          properties[:type] || :ambient
        end
        
        def strength
          properties[:strength] || 1.0
        end

        def accept(visitor)
          visitor.visit_lighting_effect(self)
        end
      end
    end
  end
end
