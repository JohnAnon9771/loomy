# frozen_string_literal: true

module Loomy
  module AST
    # A container that positions its children in its own coordinate space and
    # can carry effects applied to the composited result of all of them.
    class Group < Node
      include Positionable

      def accept(visitor) = visitor.visit_group(self)
    end
  end
end
