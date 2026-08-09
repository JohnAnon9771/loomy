# frozen_string_literal: true

module Loomy
  module Render
    # Maps effect node classes to the processor that applies them.
    #
    # Built per render from Loomy.effects, so one render works from a stable
    # snapshot rather than reading a mutable global part-way through.
    class EffectRegistry
      def initialize(processors, loader)
        @processors = processors
        @loader = loader
      end

      def self.snapshot(loader) = new(Loomy.effects.dup, loader)

      # Applies every effect in order. An effect with no registered processor is
      # left alone rather than raising: registration is open, and an unknown
      # effect is a missing feature, not a corrupt image.
      #
      # The loader is handed to the processor so an effect that reads a map from
      # disk goes through the same cache as everything else.
      def apply(image, effects)
        effects.inject(image) do |current, effect|
          processor = @processors[effect.class]
          processor ? processor.call(current, effect, @loader) : current
        end
      end
    end
  end
end
