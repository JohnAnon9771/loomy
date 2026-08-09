# frozen_string_literal: true

module Loomy
  module Layout
    # Resolves every node's size and position before a single pixel is touched.
    #
    # Two passes, the way a layout engine normally works:
    #
    #   measure  bottom-up  -- how big does each node render?
    #   arrange  top-down   -- where does it sit inside its parent?
    #
    # The result is a side table of {node => Frame}; nothing is written back into
    # the tree.
    #
    # Measuring needs intrinsic sizes, so it reads image headers -- cheap,
    # libvips does not decode pixels for that -- through the same SourceCache
    # `bounds_of` measured against and the renderer later loads from. It asks
    # for sizes and trim bounds and nothing else; no pixel reaches this pass.
    class Engine
      PERCENTAGE = /\A(-?\d+(?:\.\d+)?)%\z/

      # Fits that produce exactly the declared box. :contain is the default and
      # derives the box from the aspect ratio instead, so writing it out has to
      # mean the same as leaving it off.
      EXACT_FITS = %i[cover fill].freeze

      def initialize(sources)
        @sources = sources
        @frames = {}
      end

      # => [{node => Frame}, [canvas_width, canvas_height]]
      def call(canvas)
        size = measure(canvas, [canvas.width, canvas.height])

        [@frames, size]
      end

      private

      # ---- measure ----------------------------------------------------------

      def measure(node, box)
        case node
        when AST::Canvas, AST::Group then measure_container(node, box)
        when AST::Stack then measure_stack(node, box)
        when AST::Layer then measure_layer(node, box)
        else raise LayoutError, "Cannot measure #{node.class}"
        end
      end

      # A container without a declared size takes its parent's box; failing that
      # (an auto-sized canvas, or a group under one) it shrink-wraps its children.
      def measure_container(node, box)
        arrange_children(node, inner_box(node, box))
      end

      def measure_stack(node, box)
        arrange_stack(node, inner_box(node, box))
      end

      def inner_box(node, box)
        [declared(node, :width, box[0]) || box[0], declared(node, :height, box[1]) || box[1]]
      end

      def measure_layer(node, box)
        width  = declared(node, :width, box[0])
        height = declared(node, :height, box[1])

        fit_size(intrinsic_size(node, box, width, height), width, height, node.fit, box)
      end

      # Natural size of the layer's source, before any fit is applied.
      def intrinsic_size(node, box, width, height)
        case node.source_type
        when :file then file_intrinsic(node)
        when :text then text_intrinsic(node, width)
        else
          # Solids and gradients have no natural size: they are whatever they
          # are asked to be, falling back to the parent box.
          [numeric(width) || box[0] || 1, numeric(height) || box[1] || 1]
        end
      end

      def file_intrinsic(node)
        return @sources.dimensions(node.source) unless node.trim

        _left, _top, trim_width, trim_height = @sources.trim_bounds(node.source)
        return @sources.dimensions(node.source) unless trim_width.positive? && trim_height.positive?

        [trim_width, trim_height]
      end

      def text_intrinsic(node, width)
        mask = Render::Sources::Text.new(node, width: numeric(width)).mask

        [mask.width, mask.height]
      end

      # Applies the declared width/height and fit to an intrinsic size.
      def fit_size(intrinsic, width, height, fit, box)
        filling = width == :fill || height == :fill
        target_width  = width == :fill ? box[0] : numeric(width)
        target_height = height == :fill ? box[1] : numeric(height)

        return intrinsic if target_width.nil? && target_height.nil?

        # `width: :fill` and the exact fits all mean "be precisely this box", so
        # aspect ratio does not survive them.
        return [target_width || intrinsic[0], target_height || intrinsic[1]] if filling || EXACT_FITS.include?(fit)

        contain(intrinsic, target_width, target_height)
      end

      # Scale to fit inside the constrained axes, preserving aspect ratio.
      def contain(intrinsic, target_width, target_height)
        scales = []
        scales << target_width.fdiv(intrinsic[0]) if target_width && intrinsic[0].positive?
        scales << target_height.fdiv(intrinsic[1]) if target_height && intrinsic[1].positive?
        return intrinsic if scales.empty?

        scale = scales.min
        [(intrinsic[0] * scale).round, (intrinsic[1] * scale).round]
      end

      # ---- arrange ----------------------------------------------------------

      # Measures and places each child, and returns the box the parent ends up
      # occupying. An auto-sized parent shrink-wraps to the extent its children
      # reach at their *declared* offsets; alignment is then resolved against
      # the box that produces.
      def arrange_children(node, inner)
        sizes = node.children.map { |child| measure(child, inner) }
        box = resolve_box(inner, declared_extent(node.children, sizes))

        node.children.each_with_index do |child, index|
          record(child, Placement.resolve(child, sizes[index], box), sizes[index])
        end

        box
      end

      # Children run along the main axis; the cross axis uses the ordinary
      # placement rules, with the stack's alignment as the default.
      def arrange_stack(node, inner)
        sizes = node.children.map { |child| measure(child, inner) }
        positions = stack_positions(node, sizes, inner)

        node.children.each_with_index { |child, index| record(child, positions[index], sizes[index]) }

        resolve_box(inner, extent_of(positions, sizes))
      end

      def stack_positions(node, sizes, box)
        main = node.vertical? ? 1 : 0
        offsets = main_axis_offsets(node, sizes.map { |size| size[main] }, box[main])

        node.children.each_with_index.map do |child, index|
          stack_position(node, child, sizes[index], box, offsets[index], main)
        end
      end

      def stack_position(node, child, size, box, offset, main)
        cross = Placement.resolve(
          child, size, box,
          align_override: node.vertical? ? node.cross_align : nil,
          valign_override: node.vertical? ? nil : node.cross_align
        )

        main.zero? ? [offset, cross[1]] : [cross[0], offset]
      end

      # Running offsets along the main axis, shifted by the distribution.
      def main_axis_offsets(node, lengths, box_length)
        gap = node.spacing
        total = lengths.sum + (gap * [lengths.size - 1, 0].max)
        free = box_length ? box_length - total : 0
        start, gap = distribution(node.distribute, free, gap, lengths.size)

        lengths.each_with_object([]) do |length, offsets|
          offsets << start
          start += length + gap
        end
      end

      def distribution(mode, free, gap, count)
        case mode
        when :center then [free / 2, gap]
        when :end then [free, gap]
        when :space_between then count > 1 ? [0, gap + (free / (count - 1))] : [0, gap]
        else [0, gap]
        end
      end

      def resolve_box(inner, extent)
        [inner[0] || extent[0], inner[1] || extent[1]]
      end

      def declared_extent(children, sizes)
        positions = children.map { |child| [child.x, child.y] }

        extent_of(positions, sizes)
      end

      def extent_of(positions, sizes)
        return [1, 1] if positions.empty?

        [
          positions.zip(sizes).map { |position, size| position[0] + size[0] }.max,
          positions.zip(sizes).map { |position, size| position[1] + size[1] }.max
        ]
      end

      def record(node, position, size)
        @frames[node] = Frame.new(x: position[0], y: position[1], width: size[0], height: size[1])
      end

      # ---- declared geometry ------------------------------------------------

      # Resolves a declared dimension against the parent box. Percentages become
      # pixels; :fill and nil pass through for the caller to interpret.
      def declared(node, axis, box_length)
        value = node.public_send(axis)
        return value unless value.is_a?(String)

        match = PERCENTAGE.match(value)
        return value unless match
        raise LayoutError, "Cannot resolve #{value.inspect}: the parent has no resolvable #{axis}" if box_length.nil?

        (box_length * (match[1].to_f / 100.0)).round
      end

      def numeric(value) = value.is_a?(Numeric) ? value : nil
    end
  end
end
