# frozen_string_literal: true

module Loomy
  module Ops
    class Stack < Base
      attr_reader :direction, :spacing, :align, :valign

      def initialize(direction:, spacing: 0, align: nil, valign: nil, **options)
        super(input: nil)
        @direction = direction
        @spacing = spacing
        @align = align
        @valign = valign
        @compositor = Compositor.new(**options)
      end

      def add_layer(...) = @compositor.add_layer(...)
      def layers         = @compositor.layers

      def call(context = nil)
        prepared = @compositor.prepare(context)
        return @compositor.render([]) if prepared.empty?

        @compositor.render(arrange(prepared))
      end

      private

      def arrange(layers)
        offset = 0

        layers.each do |layer|
          if vertical?
            layer.props[:y] = offset
            layer.props[:align] ||= align

            offset += layer.image.height + spacing
          else
            layer.props[:x] = offset
            layer.props[:valign] ||= valign

            offset += layer.image.width + spacing
          end
        end
      end

      def vertical? = direction == :vertical
    end
  end
end
