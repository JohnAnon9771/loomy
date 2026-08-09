# frozen_string_literal: true

module Loomy
  module Render
    # Maps effect node classes to the processor that applies them.
    #
    # A registry is built per render from Loomy.effects, so a render works from
    # a stable snapshot rather than reading a mutable global part-way through.
    class EffectRegistry
      def initialize(processors)
        @processors = processors
      end

      def self.snapshot = new(Loomy.effects.dup)

      # Applies every effect in order. An effect with no registered processor is
      # left alone rather than raising: registration is open, and an unknown
      # effect is a missing feature, not a corrupt image.
      def apply(image, effects)
        effects.inject(image) do |current, effect|
          processor = @processors[effect.class]
          processor ? processor.call(current, effect) : current
        end
      end
    end
  end
end
