# frozen_string_literal: true

module Loomy
  module Render
    # Runs one render: lay the tree out, then paint it.
    #
    # Replaces Engine::VipsBackend, which used to build an operation tree and
    # then run an optimiser over it that recomputed what the builder had already
    # decided.
    class Pipeline
      def initialize(canvas)
        @canvas = canvas
      end

      def call
        loader = SourceLoader.new
        frames, canvas_size = Layout::Engine.new(loader).call(@canvas)

        Renderer.new(
          frames: frames,
          canvas_size: canvas_size,
          loader: loader,
          effects: EffectRegistry.snapshot
        ).call(@canvas)
      end
    end
  end
end
