require "vips"
require "zeitwerk"
require "loomy/version"

module Loomy
  class Error < StandardError; end

  loader = Zeitwerk::Loader.for_gem
  loader.inflector.inflect(
    "dsl" => "DSL",
    "ast" => "AST"
  )
  loader.setup

  class << self
    def generate(**options, &block)
      canvas = DSL::PipelineBuilder.new(options, &block).build
      canvas = AST::Optimizer.new(canvas).call
      Engine::VipsBackend.new(canvas).call
    end

    def render(output_path, **options, &block)
      image = generate(**options, &block)
      image.write_to_file(output_path)
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
  end
end

Loomy::EffectsRegistration.register_defaults
