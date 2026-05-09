# frozen_string_literal: true

module Loomy
  module Planner
    class Builder < AST::Visitor
      def initialize
        @width_stack  = []
        @height_stack = []
      end

      def build(canvas)
        @width_stack  = [canvas.width]
        @height_stack = [canvas.height]
        visit(canvas)
      end

      def visit_canvas(node)
        pipeline = Ops::Pipeline.new(
          background_width: node.width,
          background_height: node.height
        )

        node.children.each do |layer|
          pipeline.add_layer(visit(layer), layer.properties) if layer
        end

        if node.dpi
          pipeline = Ops::DpiMetadata.new(input: pipeline, dpi: node.dpi)
        end

        pipeline
      end

      def visit_group(node)
        pw = @width_stack.last
        ph = @height_stack.last

        @width_stack.push(node.width || pw)
        @height_stack.push(node.height || ph)

        pipeline = Ops::Pipeline.new(
          background_width: node.width || pw,
          background_height: node.height || ph
        )

        node.children.each { |c| pipeline.add_layer(visit(c), c.properties) if c }

        @width_stack.pop
        @height_stack.pop

        apply_effects(pipeline, node.effects)
      end

      def visit_stack(node)
        pw = @width_stack.last
        ph = @height_stack.last

        @width_stack.push(node.width || pw)
        @height_stack.push(node.height || ph)

        stack = Ops::Stack.new(
          direction: node.direction,
          spacing: node.spacing,
          align: node.align,
          valign: node.valign,
          background_width: node.width || pw,
          background_height: node.height || ph
        )

        node.children.each { |c| stack.add_layer(visit(c), c.properties) if c }

        @width_stack.pop
        @height_stack.pop

        apply_effects(stack, node.effects)
      end

      def visit_layer(node)
        op = build_base_op(node)
        return nil unless op

        op = Ops::Trim.new(input: op) if node.trim && node.source_type == :file

        w = resolve_dim(node.width, @width_stack.last)
        h = resolve_dim(node.height, @height_stack.last)

        return nil if (w.is_a?(Numeric) && w <= 0) || (h.is_a?(Numeric) && h <= 0)

        if w.is_a?(Numeric) || h.is_a?(Numeric)
          op = Ops::Resize.new(
            input: op,
            width: w.is_a?(Numeric) ? w : nil,
            height: h.is_a?(Numeric) ? h : nil,
            fit: node.fit
          )
        end

        apply_effects(op, node.effects)
      end

      private

      def build_base_op(node)
        case node.source_type
        when :file     then build_load_op(node)
        when :solid    then build_solid_op(node)
        when :text     then build_text_op(node)
        when :gradient then build_gradient_op(node)
        end
      end

      def build_load_op(node)
        w = resolve_dim(node.width, @width_stack.last)
        h = resolve_dim(node.height, @height_stack.last)

        if !node.trim && w.is_a?(Numeric)
          target_w = w
          target_h = h
          crop = :centre if node.fit == :cover
        elsif node.trim && w.is_a?(Numeric) && w < 1000
          target_w = w * 2
        end

        Ops::Load.new(node.source, target_width: target_w, target_height: target_h, crop_mode: crop)
      end

      def build_solid_op(node)
        w = node.width.is_a?(Numeric)  ? node.width  : (@width_stack.last || 1)
        h = node.height.is_a?(Numeric) ? node.height : (@height_stack.last || 1)
        Ops::Solid.new(color: node.solid, width: w, height: h)
      end

      def build_text_op(node)
        w = node.width.is_a?(Numeric) ? node.width : nil
        Ops::Text.new(
          text: node.text,
          font: node.font || 'sans',
          size: node.size || 24,
          color: node.color || '#000',
          width: w
        )
      end

      def build_gradient_op(node)
        w = node.width.is_a?(Numeric)  ? node.width  : (@width_stack.last || 1)
        h = node.height.is_a?(Numeric) ? node.height : (@height_stack.last || 1)

        Ops::Gradient.new(
          from: node.gradient[:from], to: node.gradient[:to],
          direction: node.gradient[:direction] || :top_bottom,
          width: w, height: h
        )
      end

      def apply_effects(op, effects)
        effects.inject(op) { |o, e| Ops::EffectOp.new(input: o, effect_node: e) }
      end

      def resolve_dim(value, total)
        return value unless value.is_a?(String) && value.end_with?('%')
        return value if total.nil?

        (total * (value.to_f / 100.0)).round
      end
    end
  end
end
