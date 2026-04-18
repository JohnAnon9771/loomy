# frozen_string_literal: true

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
      def trim(v)       = @layer.properties[:trim] = v
      alias blend_mode blend

      # Semantic Layout
      def align(v)      = @layer.properties[:align] = v
      def valign(v)     = @layer.properties[:valign] = v
      def anchor(v)     = @layer.properties[:anchor] = v
      def offset_x(v)   = @layer.properties[:offset_x] = v
      def offset_y(v)   = @layer.properties[:offset_y] = v

      def offset(v)
        @layer.properties[:offset_x] = v.is_a?(Array) ? v[0] : v
        @layer.properties[:offset_y] = v.is_a?(Array) ? v[1] : v
      end

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

      # Mask
      def mask(source = nil, method: :dest_in, **options)
        @layer.properties[:mask] = source || options[:path]
        @layer.properties[:mask_method] = method
      end

      # Effects
      def displace(map: nil, from_mask: nil, scale: 20, intensity: 1.0, **opts)
        if from_mask
          @layer.add_effect(AST::Effects::MaskDisplacement.new(
                              from_mask: from_mask, scale: scale, intensity: intensity, **opts
                            ))
        else
          @layer.add_effect(AST::Effects::Displacement.new(map: map, scale: scale, **opts))
        end
      end

      def relight(map: nil, from_mask: nil, strength: 1.0, type: :soft_light, **opts)
        if from_mask
          @layer.add_effect(AST::Effects::MaskLighting.new(
                              from_mask: from_mask, strength: strength, type: type, **opts
                            ))
        else
          @layer.add_effect(AST::Effects::Lighting.new(map: map, strength: strength, type: type, **opts))
        end
      end

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
