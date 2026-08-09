# frozen_string_literal: true

module Loomy
  module DSL
    # Entry point for the DSL: turns the options and block given to
    # Loomy.render / Loomy.generate into a canvas.
    class PipelineBuilder
      def initialize(options, &block)
        @options = options
        @block = block
      end

      def build
        CanvasBuilder
          .new(size: @options[:size], dpi: @options[:dpi])
          .evaluate(&@block)
          .build
      end
    end
  end
end
