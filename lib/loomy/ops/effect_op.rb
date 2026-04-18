# frozen_string_literal: true

module Loomy
  module Ops
    class EffectOp < Base
      attr_reader :effect_node

      def initialize(input:, effect_node:)
        super(input: input)
        @effect_node = effect_node
      end

      def call(context = nil)
        img = @input.call(context)
        processor = Loomy.effects[@effect_node.class]

        if processor
          processor.call(img, @effect_node)
        else
          img
        end
      end
    end
  end
end
