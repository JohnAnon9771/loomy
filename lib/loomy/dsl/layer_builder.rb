# frozen_string_literal: true

module Loomy
  module DSL
    # Builds a leaf layer. Does not include Container: a layer holds one image
    # source, not other nodes.
    class LayerBuilder < NodeBuilder
      include Effects

      # Geometry and composition.
      property :x, :y, :width, :height, :fit, :blend, :trim, :opacity

      # What Loomy.measure reports this node's frame under.
      property :name

      # Semantic layout.
      property :align, :valign, :anchor, :offset_x, :offset_y

      # Sources and their styling. Exactly one source property applies.
      property :source, :solid, :text, :gradient, :color, :font, :size

      alias blend_mode blend

      # What a text layer's height: and fit: are refused with; see
      # #refuse_a_text_box!.
      TEXT_HEIGHT_EXPECTED = 'none: a text layer is as tall as its lines, and width: sets where they break'
      TEXT_FIT_EXPECTED = ':contain: text is drawn at its font size, never scaled into a box'

      # Shorthand for offset_x/offset_y, taking either one value for both axes
      # or a [x, y] pair.
      def offset(value)
        x, y = value.is_a?(Array) ? value : [value, value]
        set(:offset_x, x)
        set(:offset_y, y)
      end

      # Asked of the built layer rather than of its properties, because which
      # source a layer draws is AST::Layer's decision and a copy of it here
      # could drift.
      def build
        super.tap { |layer| refuse_a_text_box!(layer) if layer.source_type == :text }
      end

      private

      def node_class = AST::Layer

      # A text layer is drawn at its font size and is as big as the lines pango
      # sets, so it has no box to be scaled into: `width:` is where the lines
      # break. A height or a scaling fit would describe that box, and layout
      # would size a frame the renderer never draws -- the text landing off
      # position with nothing said. `fit: :contain` passes, being the default.
      def refuse_a_text_box!(layer)
        raise InvalidValue.new(:height, layer.height, TEXT_HEIGHT_EXPECTED, 'text layer') if layer.height
        return if layer.fit.nil? || layer.fit == :contain

        raise InvalidValue.new(:fit, layer.fit, TEXT_FIT_EXPECTED, 'text layer')
      end
    end
  end
end
