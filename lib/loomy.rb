# frozen_string_literal: true

require 'vips'
require 'zeitwerk'
require 'loomy/version'
# Several constants directly under Loomy, which is not a shape Zeitwerk can
# autoload, so they are required eagerly and the file is ignored below.
require 'loomy/errors'

module Loomy
  # Options that describe the canvas itself. Everything else in the options
  # hash is forwarded to libvips as a write option. Keeping the two sets in one
  # constant is what stops `render` and `to_blob` from drifting apart -- they
  # used to slice different key lists, so `to_blob` silently dropped `dpi`.
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
    def generate(**options, &)
      canvas = DSL::PipelineBuilder.new(options, &).build
      canvas = AST::Optimizer.new(canvas).call
      Engine::VipsBackend.new(canvas).call
    end

    def render(output_path, **options, &)
      image = generate(**canvas_options(options), &)
      image.write_to_file(output_path, **write_options(options))
    end

    def to_blob(format, **options, &)
      image = generate(**canvas_options(options), &)
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

    def canvas_options(options)
      options.slice(*CANVAS_OPTIONS)
    end

    def write_options(options)
      options.except(*CANVAS_OPTIONS).transform_keys { |k| WRITE_OPTION_ALIASES.fetch(k, k) }
    end
  end
end

Loomy::EffectsRegistration.register_defaults
