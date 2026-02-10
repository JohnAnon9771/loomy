require_relative "../ast/node"

module Loomy
  module DSL
    class LayerBuilder
      def initialize(layer)
        @layer = layer
      end

      def evaluate(&block)
        instance_eval(&block) if block_given?
      end
      
      # Properties
      def x(value)
        @layer.properties[:x] = value
      end

      def y(value)
        @layer.properties[:y] = value
      end

      def width(value)
        @layer.properties[:width] = value
      end

      def height(value)
        @layer.properties[:height] = value
      end
      
      def fit(value)
        @layer.properties[:fit] = value
      end
      
      def blend(value)
        @layer.properties[:blend] = value
      end
      
      def trim(value)
        @layer.properties[:trim] = value
      end
      
      ### Styles
      def use(style_name)
        block = Loomy.styles[style_name]
        raise ArgumentError, "Style '#{style_name}' not defined" unless block
        
        evaluate(&block)
      end
      
      alias_method :blend_mode, :blend

      def displace(map:, scale: 20, **options)
        effect = AST::Effects::Displacement.new(map: map, scale: scale, **options)
        @layer.add_effect(effect)
      end

      def relight(map:, **options)
        effect = AST::Effects::Lighting.new(map: map, **options)
        @layer.add_effect(effect)
      end

      def blur(radius:)
        effect = AST::Effects::Blur.new(radius: radius)
        @layer.add_effect(effect)
      end

      def grayscale
        effect = AST::Effects::Grayscale.new
        @layer.add_effect(effect)
      end

      def adjust_color(**options)
        effect = AST::Effects::ColorAdjustment.new(**options)
        @layer.add_effect(effect)
      end

      # Nested structure support
      def layer(source, **options, &block)
        node = AST::Layer.new(source: source, **options)
        @layer.add_child(node)
        LayerBuilder.new(node).evaluate(&block) if block_given?
        node
      end

      def group(**options, &block)
        node = AST::Group.new(options)
        @layer.add_child(node)
        LayerBuilder.new(node).evaluate(&block) if block_given?
        node
      end
    end
  end
end
