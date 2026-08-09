# frozen_string_literal: true

module Loomy
  module DSL
    # Builds a stack: a container that lays its children along one axis.
    class StackBuilder < NodeBuilder
      include Container
      include Effects

      property :x, :y, :width, :height, :blend, :opacity
      property :anchor, :offset_x, :offset_y

      # Cross-axis alignment of the children: `align` for a vertical stack,
      # `valign` for a horizontal one.
      property :align, :valign

      # Main-axis distribution: :start, :center, :end or :space_between.
      property :distribute

      property :spacing, :direction

      alias blend_mode blend

      private

      def node_class = AST::Stack
    end
  end
end
