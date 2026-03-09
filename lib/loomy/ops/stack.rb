module Loomy
  module Ops
    class Stack < Base
      attr_reader :direction, :spacing, :align, :valign

      def initialize(direction:, spacing: 0, align: nil, valign: nil, background_width: nil, background_height: nil)
        super(input: nil)
        @direction, @spacing, @align, @valign = direction, spacing, align, valign
        @compositor = Compositor.new(background_width: background_width, background_height: background_height)
      end

      def add_layer(op, properties = {})
        @compositor.add_layer(op, properties)
      end
      def layers = @compositor.layers

      def call(context = nil)
        prepared = @compositor.prepare(context)
        return @compositor.render([]) if prepared.empty?

        layout!(prepared)
        @compositor.render(prepared)
      end

      private

      def layout!(layers)
        layers.reduce(0) do |offset, layer|
          size = if direction == :vertical
            layer.props[:y]     = offset
            layer.props[:align] ||= align
            layer.image.height
          else
            layer.props[:x]      = offset
            layer.props[:valign] ||= valign
            layer.image.width
          end

          offset + size + spacing
        end
      end
    end
  end
end
