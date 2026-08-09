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

      # Applies every effect in order. An effect with no registered processor
      # raises rather than being skipped: skipping returns an image the
      # declaration did not ask for with nothing saying so. Lookup is by exact
      # class, so a subclass of a registered effect raises too -- inheriting the
      # parent's processor would read the subclass' parameters as the parent's.
      #
      # The loader is handed to the processor so an effect that reads a map from
      # disk goes through the same cache as everything else.
      def apply(image, effects)
        effects.inject(image) do |current, effect|
          processor = @processors[effect.class]
          raise UnknownEffect.new(effect.class, @processors.keys) unless processor

          processor.call(current, effect, @loader)
        end
      end
    end
  end
end
