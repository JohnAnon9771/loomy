# frozen_string_literal: true

module Loomy
  module DSL
    # Base for the block-form builders.
    #
    # A builder accumulates properties, children and effects and only then
    # constructs the node, which is why AST nodes can be frozen. Builders used
    # to write straight into the properties hash of an already-built node.
    #
    # Each node kind gets its own builder exposing only what that kind supports,
    # so `solid` inside a `group`, or a nested `layer` inside a leaf `layer`,
    # now fails with a message instead of being accepted and ignored.
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

      def build
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
