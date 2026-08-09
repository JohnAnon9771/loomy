# frozen_string_literal: true

module Loomy
  module Render
    # Which sources can be read as a single downward pass, and so streamed
    # rather than decoded whole.
    #
    # The answer is conservative on purpose: a source that streams and is then
    # read a second time fails with `out of order read`, and a source opened
    # for streaming cannot be rewound. So this names only what it can prove is
    # read exactly once, in order, and everything else keeps random access.
    #
    # Three declarations disqualify a source, all visible in the tree before a
    # file is opened:
    #
    #   read twice  the same file behind two layers, or behind a layer and an
    #               effect map, is two passes over one handle
    #   trim        the scan is eager whichever mode it runs in: it consumes the
    #               whole image during the measure pass, and the render then
    #               reads it again from the top
    #   displace    mapim indexes its input out of order. libvips buffers enough
    #               lines to absorb a small displacement -- 4200x4800 at scale
    #               500 streams fine, at scale 2000 it runs past the buffer --
    #               but where that line falls depends on the source's height,
    #               so it is not a promise to make
    #
    # The obvious fix for the first two is to give each reader a handle of its
    # own, which the SourceCache/SourceLoader split makes easy. Measured, and it
    # is the wrong trade: on a 4200x4800 source with `trim:` it takes peak RSS
    # from 240 MB to 176 MB and the render from 77 ms to 244 ms. One :random
    # handle decodes the source once and serves both the scan and the pixels;
    # two streamed handles decode it twice. This is a memory problem, and 3.2x
    # the latency is not the way to pay for it.
    class AccessPlan
      def self.streamable(canvas) = new(canvas).streamable

      def initialize(canvas)
        @canvas = canvas
      end

      def streamable = read_once - trimmed - displaced

      private

      def read_once
        reads.tally.filter_map { |path, count| path if count == 1 }.to_set
      end

      # Every read the render will make.
      def reads = effect_maps + file_layers(@canvas).map(&:source)

      # A map is found by property rather than by effect class, so a registered
      # effect that names its map `map:` is counted like the built-in ones. One
      # that reads a file under some other name is simply never named here,
      # which leaves its source on random access -- the safe side.
      def effect_maps
        nodes(@canvas).flat_map(&:effects).filter_map { |effect| effect.properties[:map] }
      end

      def trimmed = file_layers(@canvas).select(&:trim).to_set(&:source)

      # The effect can sit on a container, in which case every file underneath
      # it is read through the same out-of-order index.
      def displaced
        nodes(@canvas).select { |node| node.effects.any?(AST::Effects::Displacement) }
                      .flat_map { |node| file_layers(node).map(&:source) }
                      .to_set
      end

      def file_layers(root)
        nodes(root).select { |node| node.is_a?(AST::Layer) && node.source_type == :file }
      end

      def nodes(root) = [root] + root.children.flat_map { |child| nodes(child) }
    end
  end
end
