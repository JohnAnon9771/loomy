# frozen_string_literal: true

module Loomy
  module DSL
    # Effect declarations, shared by every builder whose node can carry effects.
    #
    # Note these take keyword arguments rather than a single value, which is why
    # they are not NodeBuilder.property declarations.
    module Effects
      def blur(radius:) = add_effect(AST::Effects::Blur.new(radius: radius))

      def grayscale = add_effect(AST::Effects::Grayscale.new)

      def adjust_color(**) = add_effect(AST::Effects::ColorAdjustment.new(**))

      def displace(map:, scale: 20, **)
        add_effect(AST::Effects::Displacement.new(map: map, scale: scale, **))
      end

      def relight(map:, **) = add_effect(AST::Effects::Lighting.new(map: map, **))
    end
  end
end
