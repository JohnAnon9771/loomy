# frozen_string_literal: true

module Loomy
  module DSL
    # Builds a group: a container that positions its children in its own space
    # and can carry effects over the composited result.
    class GroupBuilder < NodeBuilder
      include Container
      include Effects

      property :x, :y, :width, :height, :blend
      property :align, :valign, :anchor, :offset_x, :offset_y

      alias blend_mode blend

      private

      def node_class = AST::Group
    end
  end
end
