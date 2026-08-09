# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Blur < Effect
        def radius = properties[:radius] || 0

        def no_op? = radius <= 0
      end
    end
  end
end
