# frozen_string_literal: true

require 'vips'
require 'zeitwerk'
require 'loomy/version'

module Loomy
  class Error < StandardError; end

  WRITE_OPTION_ALIASES = {
    quality: :Q
  }.freeze

  loader = Zeitwerk::Loader.for_gem
  loader.inflector.inflect(
    'dsl' => 'DSL',
    'ast' => 'AST'
  )
  loader.setup

  class << self
    def generate(**options, &block)
      canvas = DSL::PipelineBuilder.new(options, &block).build
      canvas = AST::Optimizer.new(canvas).call
      Engine::VipsBackend.new(canvas).call
    end

    def render(output_path, **options, &block)
      image = generate(**options.slice(:size), &block)
      image.write_to_file(output_path, **write_options(options))
    end

    def to_blob(format, **options, &block)
      image = generate(**options.slice(:size), &block)
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

    def write_options(options)
      options.except(:size).transform_keys { |k| WRITE_OPTION_ALIASES.fetch(k, k) }
    end
  end
end

Loomy::EffectsRegistration.register_defaults
