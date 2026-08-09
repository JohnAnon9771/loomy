# frozen_string_literal: true

module Loomy
  module DSL
    # Builds the root canvas. Its size and dpi come from the Loomy.render /
    # Loomy.generate options, so it exposes nesting only.
    #
    # Used to live inside dsl/pipeline_builder.rb, where Zeitwerk could not
    # autoload it -- tests had to `require 'loomy/dsl/pipeline_builder'` by hand
    # to get at it.
    class CanvasBuilder < NodeBuilder
      include Container

      private

      def node_class = AST::Canvas
    end
  end
end
