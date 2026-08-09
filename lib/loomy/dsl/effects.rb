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

      def adjust_color(brightness: nil, contrast: nil)
        add_effect(AST::Effects::ColorAdjustment.new(brightness: brightness, contrast: contrast))
      end

      def displace(map:, scale: 20, **)
        add_effect(AST::Effects::Displacement.new(map: map, scale: scale, **))
      end

      # `type` picks how the map is read as light and `strength` how far it is
      # pushed. The type is checked here because the effect node is built
      # directly, not through the builder where properties meet their
      # vocabulary. Nils fall through to the node's own defaults: AST::Node
      # compacts the property hash.
      def relight(map:, type: nil, strength: nil)
        effect = AST::Effects::Lighting.new(map: map, type: type, strength: strength)
        Vocabulary.validate_lighting_type!(effect.type)

        add_effect(effect)
      end
    end
  end
end
