# frozen_string_literal: true

module Loomy
  module DSL
    # Entry point for the DSL: turns the options and block given to
    # Loomy.render / Loomy.generate into a canvas.
    class PipelineBuilder
      def initialize(sources, options, &block)
        @sources = sources
        @options = options
        @block = block
      end

      # Sliced rather than spelled out one keyword at a time: Loomy.generate
      # hands the whole options hash over while render and to_blob hand one they
      # already sliced, so slicing here makes both routes identical and leaves
      # CANVAS_OPTIONS the only place a canvas option is named.
      #
      # The compact is load-bearing. Vocabulary.validate! runs inside build,
      # before AST::Node drops nils, so without it a canvas that never mentioned
      # an option would arrive carrying it as nil and be checked against a
      # vocabulary that has no nil in it -- rejecting every render.
      def build
        CanvasBuilder
          .new(@sources, @options.slice(*CANVAS_OPTIONS).compact)
          .evaluate(&@block)
          .build
      end
    end
  end
end
