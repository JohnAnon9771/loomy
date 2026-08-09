# frozen_string_literal: true

module Loomy
  module AST
    # Drops everything that provably cannot contribute a pixel, before any
    # layout or rendering work happens:
    #
    #   * layers with no usable source (no file, no text, empty string, ...)
    #   * effects that report themselves as no-ops
    #   * containers left empty once their children were dropped
    #
    # Rebuilds the tree instead of editing it in place, because AST nodes are
    # frozen. This replaces AST::Optimizer, whose name collided with the
    # (removed) Planner::Optimizer and whose effect handling was a closed set of
    # hardcoded visitor methods.
    class Pruner
      def initialize(canvas)
        @canvas = canvas
      end

      def call = prune(@canvas)

      private

      def prune(node)
        case node
        when Canvas then node.with(children: prune_children(node))
        when Group, Stack then prune_container(node)
        when Layer then prune_layer(node)
        else node
        end
      end

      def prune_container(node)
        children = prune_children(node)
        return nil if children.empty?

        node.with(children: children, effects: live_effects(node))
      end

      def prune_layer(node)
        return nil unless renderable?(node)

        node.with(effects: live_effects(node))
      end

      def prune_children(node)
        node.children.filter_map { |child| prune(child) }
      end

      def live_effects(node)
        node.effects.reject(&:no_op?)
      end

      def renderable?(node)
        case node.source_type
        when nil then false
        when :text then !node.text.to_s.empty?
        when :file then !node.source.to_s.empty?
        else true
        end
      end
    end
  end
end
