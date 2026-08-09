# frozen_string_literal: true

module Loomy
  module AST
    # A container that lays its children out along one axis.
    #
    # Cross-axis alignment of the children is `align` for a vertical stack and
    # `valign` for a horizontal one -- whichever names the axis the children are
    # *not* stacked along. `distribute` is the main axis.
    class Stack < Node
      include Positionable

      DIRECTIONS = %i[vertical horizontal].freeze
      DISTRIBUTIONS = %i[start center end space_between].freeze

      def direction = properties[:direction]
      def spacing   = properties[:spacing] || 0

      def vertical? = direction == :vertical

      # Cross-axis alignment for the children, picked by direction so callers
      # do not have to branch.
      def cross_align = vertical? ? align : valign

      def distribute = properties[:distribute] || :start

      def accept(visitor) = visitor.visit_stack(self)
    end
  end
end
