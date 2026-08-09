# frozen_string_literal: true

module Loomy
  module AST
    # Base class for effects attached to a layer, group or stack.
    #
    # Effects carry parameters only; what they do to pixels lives in the effect
    # registry (see Loomy.register_effect), keyed by class.
    class Effect < Node
      # True when this effect provably cannot change a pixel, so passes can drop
      # it. The pruner used to hardcode one visitor method per built-in effect,
      # which meant a third-party effect could never take part in this.
      def no_op? = false

      def accept(visitor) = visitor.visit_effect(self)
    end
  end
end
