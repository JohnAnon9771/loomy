# frozen_string_literal: true

module Loomy
  module AST
    # A leaf: exactly one image source, optionally resized, trimmed and filtered.
    # Layers do not contain other nodes -- use a group or a stack for that.
    class Layer < Node
      include Positionable

      # Which of the mutually exclusive source properties this layer carries.
      # nil means the layer cannot produce an image and gets pruned.
      def source_type
        return :file     if properties[:source]
        return :solid    if properties[:solid]
        return :text     if properties[:text]

        :gradient if properties[:gradient]
      end

      def source   = properties[:source]
      def solid    = properties[:solid]
      def text     = properties[:text]
      def gradient = properties[:gradient]
      def color    = properties[:color]
      def font     = properties[:font]
      def size     = properties[:size]

      def fit  = properties[:fit]
      def trim = properties[:trim]

      def accept(visitor) = visitor.visit_layer(self)
    end
  end
end
