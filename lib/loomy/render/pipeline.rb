# frozen_string_literal: true

module Loomy
  module Render
    # Runs one render: lay the tree out, then paint it.
    class Pipeline
      def initialize(canvas, sources)
        @canvas = canvas
        @sources = sources
      end

      def call
        frames, canvas_size = Layout::Engine.new(@sources).call(@canvas)
        loader = SourceLoader.new(@sources)

        Renderer.new(
          frames: frames,
          canvas_size: canvas_size,
          loader: loader,
          effects: EffectRegistry.snapshot(loader)
        ).call(@canvas)
      end
    end
  end
end
