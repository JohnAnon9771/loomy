# frozen_string_literal: true

require 'vips'
require 'zeitwerk'
require 'loomy/version'
# Several constants directly under Loomy, which is not a shape Zeitwerk can
# autoload, so they are required eagerly and the file is ignored below.
require 'loomy/errors'

module Loomy
  # Options that describe the canvas itself. Everything else in the options hash
  # is forwarded to libvips as a write option, so every entry point has to split
  # them on this one list.
  CANVAS_OPTIONS = %i[size dpi].freeze

  WRITE_OPTION_ALIASES = {
    quality: :Q
  }.freeze

  loader = Zeitwerk::Loader.for_gem
  loader.inflector.inflect(
    'dsl' => 'DSL',
    'ast' => 'AST'
  )
  loader.ignore("#{__dir__}/loomy/errors.rb")
  loader.setup

  class << self
    # Hands the image back lazily, so the caller decides when and how often to
    # read it. Every source therefore stays on random access.
    def generate(**options, &)
      canvas, loader = compose(options, &)

      Render::Pipeline.new(canvas, loader).call
    end

    def render(output_path, **options, &)
      image = single_pass(canvas_options(options), &)
      image.write_to_file(output_path, **write_options(options))
    end

    def to_blob(format, **options, &)
      image = single_pass(canvas_options(options), &)
      image.write_to_buffer(format, **write_options(options))
    end

    def styles
      @styles ||= {}
    end

    def define_style(name, &block)
      styles[name] = block
    end

    def effects
      @effects ||= {}
    end

    def register_effect(klass, processor)
      effects[klass] = processor
    end

    private

    # One loader per render, built before the block is evaluated: `bounds_of`
    # measures a source while the DSL is still running, and has to see the same
    # orientation, threshold and cache the render will.
    def compose(options, &)
      loader = Render::SourceLoader.new
      canvas = DSL::PipelineBuilder.new(loader, options, &).build

      [AST::Pruner.new(canvas).call, loader]
    end

    # The image is written once and dropped, so the sources the tree reads once
    # can be streamed rather than decoded whole. That is the whole memory
    # difference between this and `generate`, whose result the caller may read
    # any number of times.
    def single_pass(options, &)
      canvas, loader = compose(options, &)
      loader.allow_streaming(Render::AccessPlan.streamable(canvas))

      Render::Pipeline.new(canvas, loader).call
    end

    def canvas_options(options)
      options.slice(*CANVAS_OPTIONS)
    end

    def write_options(options)
      options.except(*CANVAS_OPTIONS).transform_keys { |key| WRITE_OPTION_ALIASES.fetch(key, key) }
    end
  end
end

Loomy::EffectsRegistration.register_defaults
