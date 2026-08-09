# frozen_string_literal: true

module Loomy
  module DSL
    # Nesting methods, for the builders whose node can hold children: the canvas,
    # groups and stacks. Leaf layers deliberately do not include this, so a
    # nested `layer` inside a layer is rejected rather than quietly dropped.
    module Container
      def layer(source = nil, **, &)
        add_child(LayerBuilder.new(loader, source: source, **).evaluate(&).build)
      end

      def group(**options, &)
        add_child(GroupBuilder.new(loader, options).evaluate(&).build)
      end

      def stack(direction, **options, &)
        add_child(StackBuilder.new(loader, options.merge(direction: direction)).evaluate(&).build)
      end

      def vstack(**, &) = stack(:vertical, **, &)
      def hstack(**, &) = stack(:horizontal, **, &)

      # Opaque extent of an image on disk, for positioning against artwork whose
      # content does not fill its canvas.
      #
      # Measured through the loader the render will use, so it agrees with what
      # `trim:` crops to: same orientation, same threshold, same scan.
      def bounds_of(source)
        left, top, width, height = loader.trim_bounds(source)

        Bounds.new(x: left, y: top, width: width, height: height)
      end
    end
  end
end
