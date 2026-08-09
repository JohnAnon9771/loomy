# frozen_string_literal: true

module Loomy
  module AST
    # Base class for every node in the tree.
    #
    # Nodes are immutable: properties, children and effects are frozen at
    # construction, and passes that change the tree rebuild it with #with. That
    # is what lets the same tree render twice and give the same image.
    #
    # `properties` is positional rather than a keyword argument so that nodes
    # can still be built as `Blur.new(radius: 5)`.
    class Node
      attr_reader :properties, :children, :effects

      def initialize(properties = {}, children = [], effects = [])
        @properties = properties.compact.freeze
        @children   = children.freeze
        @effects    = effects.freeze
      end

      # Copy of this node with children and/or effects replaced.
      def with(children: @children, effects: @effects)
        self.class.new(@properties, children, effects)
      end

      def accept(visitor)
        visitor.visit_node(self)
      end
    end
  end
end
