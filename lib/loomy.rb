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
  #
  # It is also the list DSL::PipelineBuilder builds the canvas' properties from,
  # so naming an option here is all a new one needs to reach the tree -- and it
  # cannot reach the saver by accident, which is the divergence #19 was.
  CANVAS_OPTIONS = %i[size dpi premultiplied].freeze

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
      canvas, sources = compose(options, &)

      Render::Pipeline.new(canvas, sources).call
    end

    def render(output_path, **options, &)
      image, sources = single_pass(canvas_options(options), &)

      encoding(output_path, sources) { image.write_to_file(output_path, **write_options(options)) }
    end

    def to_blob(format, **options, &)
      image, sources = single_pass(canvas_options(options), &)

      encoding(format, sources) { image.write_to_buffer(format, **write_options(options)) }
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

    # One source cache per render, built before the block is evaluated:
    # `bounds_of` measures a source while the DSL is still running, and has to
    # see the same orientation, threshold and scan the render will.
    def compose(options, &)
      sources = Render::SourceCache.new
      canvas = DSL::PipelineBuilder.new(sources, options, &).build

      [AST::Pruner.new(canvas).call, sources]
    end

    # The image is written once and dropped, so the sources the tree reads once
    # can be streamed rather than decoded whole. That is the whole memory
    # difference between this and `generate`, whose result the caller may read
    # any number of times.
    #
    # The cache comes back out alongside the image because the write is the first
    # thing to read any pixels, so it is the write that finds out whether the
    # sources were readable.
    def single_pass(options, &)
      canvas, sources = compose(options, &)
      sources.allow_streaming(Render::AccessPlan.streamable(canvas))

      [Render::Pipeline.new(canvas, sources).call, sources]
    end

    # Two unrelated failures meet here. libvips is demand-driven, so the write is
    # the first thing to read a source's pixels at all: a truncated file fails in
    # the same call an unsupported format does, and a caller deciding between
    # "the image you sent is broken" and "our options are wrong" gets one
    # Vips::Error for both. Hence the re-read to tell them apart -- a decode per
    # source, paid only after a failure, never on the way to a render that works.
    def encoding(target, sources)
      yield
    rescue TypeError => e
      # ruby-vips converts write options to the types libvips declared them with,
      # so `quality: 'high'` fails before libvips is reached and before anything
      # was read. Nothing to attribute.
      raise EncodeError.new(target, e.message)
    rescue Vips::Error => e
      path = sources.undecodable_path

      raise InvalidSource.new(path, e.message) if path

      raise EncodeError.new(target, e.message)
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
