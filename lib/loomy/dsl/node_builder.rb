# frozen_string_literal: true

module Loomy
  module DSL
    # Base for the block-form builders.
    #
    # A builder accumulates properties, children and effects and constructs the
    # node only at the end, which is what lets AST nodes be frozen.
    #
    # Each node kind gets its own builder exposing only what that kind supports,
    # so `solid` inside a `group` fails with a message naming what is available.
    class NodeBuilder
      class << self
        # Declares `name(value)` writers that set the property of the same name.
        def property(*names)
          names.each do |name|
            define_method(name) { |value| set(name, value) }
          end
        end

        # Everything callable inside this builder's block, for error messages.
        def dsl_methods
          (instance_methods - NodeBuilder.instance_methods).sort
        end

        # Human-readable node kind, e.g. "a layer".
        def dsl_name
          name.split('::').last.sub('Builder', '').downcase
        end
      end

      def initialize(properties = {})
        @properties = properties.dup
        @children = []
        @effects = []
      end

      def evaluate(&block)
        instance_eval(&block) if block
        self
      end

      # Both forms of the DSL funnel through here -- keyword arguments went into
      # @properties at construction, block calls wrote to it since -- so it is
      # the one place that sees every value a node was given.
      def build
        Vocabulary.validate!(@properties, self.class.dsl_name)

        node_class.new(@properties, @children, @effects)
      end

      # Applies a style defined with Loomy.define_style.
      def use(style_name)
        block = Loomy.styles[style_name]
        raise UnknownStyle.new(style_name, Loomy.styles.keys) unless block

        instance_eval(&block)
      end

      private

      def node_class
        raise NotImplementedError, "#{self.class} must define #node_class"
      end

      def set(key, value)
        @properties[key] = value
      end

      def add_child(node)
        @children << node
        node
      end

      def add_effect(effect)
        @effects << effect
        effect
      end

      # instance_eval means an unknown call inside a DSL block would otherwise
      # surface as a bare NoMethodError on the builder.
      def method_missing(name, *_args)
        raise UnknownProperty.new(name, self.class.dsl_name, self.class.dsl_methods)
      end

      def respond_to_missing?(name, include_private = false)
        self.class.dsl_methods.include?(name) || super
      end
    end
  end
end
