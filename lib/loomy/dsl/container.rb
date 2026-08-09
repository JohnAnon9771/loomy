# frozen_string_literal: true

module Loomy
  module DSL
    # Nesting methods, for the builders whose node can hold children: the canvas,
    # groups and stacks. Leaf layers deliberately do not include this, so a
    # nested `layer` inside a layer is rejected rather than quietly dropped.
    module Container
      def layer(source = nil, **, &)
        add_child(LayerBuilder.new(sources, source: source, **).evaluate(&).build)
      end

      def group(**options, &)
        add_child(GroupBuilder.new(sources, options).evaluate(&).build)
      end

      def stack(direction, **options, &)
        add_child(StackBuilder.new(sources, options.merge(direction: direction)).evaluate(&).build)
      end

      def vstack(**, &) = stack(:vertical, **, &)
      def hstack(**, &) = stack(:horizontal, **, &)

      # Content extent of an image on disk, for positioning against artwork
      # whose content does not fill its canvas.
      #
      # Measured through the cache the render will use, so it agrees with what
      # `trim:` crops to: same orientation, same scan. `mode` is `trim:`'s, and
      # takes the same values, because measuring one way and cropping the other
      # is how the two come apart.
      def bounds_of(source, mode = :auto)
        left, top, width, height = sources.trim_bounds(source, mode)

        Bounds.new(x: left, y: top, width: width, height: height)
      end
    end
  end
end
