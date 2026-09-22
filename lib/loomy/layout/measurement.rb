# frozen_string_literal: true

module Loomy
  module Layout
    # What Loomy.measure hands back: the frame of every named node, in canvas
    # coordinates.
    #
    # The engine records each frame against its parent's box, which is what the
    # renderer composites with; a caller placing something at canvas level
    # needs the sum of every origin above it, so that is what is stored.
    class Measurement
      attr_reader :size

      # `declared` is the tree before pruning. Names are collected from it, so a
      # duplicate is refused even when one of the pair draws nothing, and `fetch`
      # can tell a pruned node from a typo.
      def initialize(declared, canvas, frames, size)
        @size = size
        @declared = names_in(declared, Set.new)
        @frames = {}
        place(canvas, Frame.new(x: 0, y: 0, width: size[0], height: size[1]), frames)
        @frames.freeze
        freeze
      end

      # The node's Frame, or nil when there is none -- never declared, or pruned.
      def [](name) = @frames[name]

      def fetch(name)
        @frames.fetch(name) { raise UnknownNode.new(name, @frames.keys, @declared) }
      end

      def to_h = @frames

      private

      def names_in(node, names)
        node.children.each do |child|
          name = child.name
          raise DuplicateName, name if name && !names.add?(name)

          names_in(child, names)
        end

        names
      end

      def place(node, parent, frames)
        node.children.each do |child|
          relative = frames.fetch(child)
          frame = relative.with(x: parent.x + relative.x, y: parent.y + relative.y)
          @frames[child.name] = frame if child.name

          place(child, frame, frames)
        end
      end
    end
  end
end
