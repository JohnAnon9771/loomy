# frozen_string_literal: true

module Loomy
  module DSL
    # Builds a leaf layer. Does not include Container: a layer holds one image
    # source, not other nodes.
    class LayerBuilder < NodeBuilder
      include Effects

      # Geometry and composition.
      property :x, :y, :width, :height, :fit, :blend, :trim, :opacity

      # Semantic layout.
      property :align, :valign, :anchor, :offset_x, :offset_y

      # Sources and their styling. Exactly one source property applies.
      property :source, :solid, :text, :gradient, :color, :font, :size

      alias blend_mode blend

      # Shorthand for offset_x/offset_y, taking either one value for both axes
      # or a [x, y] pair.
      def offset(value)
        x, y = value.is_a?(Array) ? value : [value, value]
        set(:offset_x, x)
        set(:offset_y, y)
      end

      private

      def node_class = AST::Layer
    end
  end
end
