# frozen_string_literal: true

module Loomy
  module Render
    # Runs one render: lay the tree out, then paint it.
    class Pipeline
      def initialize(canvas, sources)
        @canvas = canvas
        @sources = sources
      end

      # One rescue covers the whole pass because libvips checks an operation's
      # arguments as it is built, not when its pixels are pulled, so anything it
      # will refuse raises inside this call. Its message names the operation and
      # #cause keeps the backtrace, which is why BackendError needs no detail of
      # its own. A source failure is already an InvalidSource by now, and that is
      # not a Vips::Error, so it passes through.
      def call
        frames, canvas_size = Layout::Engine.new(@sources).call(@canvas)
        loader = SourceLoader.new(@sources)

        Renderer.new(
          frames: frames,
          canvas_size: canvas_size,
          loader: loader,
          effects: EffectRegistry.snapshot(loader)
        ).call(@canvas)
      rescue Vips::Error => e
        raise BackendError.new('Building the render', e.message)
      end
    end
  end
end
