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

      # Geometry & Composition
      def x(v)          = @layer.properties[:x] = v
      def y(v)          = @layer.properties[:y] = v
      def width(v)      = @layer.properties[:width] = v
      def height(v)     = @layer.properties[:height] = v
      def fit(v)        = @layer.properties[:fit] = v
      def blend(v)      = @layer.properties[:blend] = v
      alias_method :blend_mode, :blend
      def trim(v)       = @layer.properties[:trim] = v

      # Procedural Sources
      def source(v)     = @layer.properties[:source] = v
      def solid(v)      = @layer.properties[:solid] = v
      def text(v)       = @layer.properties[:text] = v
      def gradient(v)   = @layer.properties[:gradient] = v
      def color(v)      = @layer.properties[:color] = v
      def font(v)       = @layer.properties[:font] = v
      def size(v)       = @layer.properties[:size] = v

      def use(style_name)
        block = Loomy.styles[style_name]
        raise ArgumentError, "Style '#{style_name}' not defined" unless block

        evaluate(&block)
      end

      # Effects
      def displace(map:, scale: 20, **opts) = @layer.add_effect(AST::Effects::Displacement.new(map: map, scale: scale, **opts))
      def relight(map:, **opts)             = @layer.add_effect(AST::Effects::Lighting.new(map: map, **opts))
      def blur(radius:)                     = @layer.add_effect(AST::Effects::Blur.new(radius: radius))
      def grayscale                         = @layer.add_effect(AST::Effects::Grayscale.new)
      def adjust_color(**opts)              = @layer.add_effect(AST::Effects::ColorAdjustment.new(**opts))

      # Nested structure support
      def layer(source = nil, **options, &block)
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
