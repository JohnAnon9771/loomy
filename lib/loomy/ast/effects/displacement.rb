# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Displacement < Effect
        def scale = properties[:scale] || 20
        def map   = properties[:map]

        def no_op? = scale.zero?
      end
    end
  end
end
