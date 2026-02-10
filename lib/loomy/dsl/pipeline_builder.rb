module Loomy
  module DSL
    class PipelineBuilder
      def initialize(options, &block)
        @options = options
        @block = block
      end

      def build
        # In MVP, we assume the outer block defines a canvas-like structure
        # or we wrapp it. For the prompt example: Loomy.render "file", size: [w, h] do ...
        # The options contain size.

        canvas = AST::Canvas.new(size: @options[:size])
        CanvasBuilder.new(canvas).evaluate(&@block)
        canvas
      end
    end

    class CanvasBuilder
      def initialize(canvas)
        @canvas = canvas
      end

      def evaluate(&block)
        instance_eval(&block) if block_given?
      end

      def layer(source, **options, &block)
        add_layer(source, options, &block)
      end

      # Specialized layer aliases from the example
      def template(source, **options, &block)
        add_layer(source, options.merge(role: :template), &block)
      end

      def mask(source, **options, &block)
        add_layer(source, options.merge(role: :mask), &block)
      end

      def artwork(source, **options, &block)
        add_layer(source, options.merge(role: :artwork), &block)
      end

      def group(**options, &block)
        node = AST::Group.new(options)
        @canvas.add_child(node)

        if block_given?
          LayerBuilder.new(node).evaluate(&block)
        end
        node
      end

      private

      def add_layer(source, options, &block)
        node = AST::Layer.new(source: source, **options)
        @canvas.add_child(node)

        # Evaluate block with LayerBuilder if provided
        if block_given?
          LayerBuilder.new(node).evaluate(&block)
        end
      end
    end
  end
end
