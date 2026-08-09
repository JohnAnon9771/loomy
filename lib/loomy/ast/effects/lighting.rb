# frozen_string_literal: true

module Loomy
  module AST
    module Effects
      class Lighting < Effect
        def type     = properties[:type] || :ambient
        def strength = properties[:strength] || 1.0
        def map      = properties[:map]

        def no_op? = strength <= 0
      end
    end
  end
end
