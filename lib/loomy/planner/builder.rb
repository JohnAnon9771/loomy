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
        pipeline = Ops::Pipeline.new(background_width: node.width, background_height: node.height)

        node.children.each do |layer|
          pipeline.add_layer(visit(layer), layer.properties) if layer
        end

        pipeline
      end

      def visit_group(node)
        pw = @width_stack.last
        ph = @height_stack.last

        w = resolve_width(node.width, pw)
        h = resolve_height(node.height, ph)

        @width_stack.push(w)
        @height_stack.push(h)

        pipeline = Ops::Pipeline.new(background_width: w, background_height: h)

        node.children.each { |c| pipeline.add_layer(visit(c), c.properties) if c }

        @width_stack.pop
        @height_stack.pop

        apply_effects(pipeline, node.effects)
      end

      def visit_layer(node)
        op = build_base_op(node)
        return nil unless op

        op = Ops::Trim.new(input: op) if node.trim && node.source_type == :file

        pw = @width_stack.last
        ph = @height_stack.last

        w = resolve_width(node.width, pw)
        h = resolve_height(node.height, ph)

        if w.is_a?(Numeric) || h.is_a?(Numeric)
          op = Ops::Resize.new(
            input: op,
            width: w.is_a?(Numeric) ? w : nil,
            height: h.is_a?(Numeric) ? h : nil,
            fit: node.fit
          )
        end

        op = apply_effects(op, node.effects)

        if node.properties[:mask]
          mask_op = Ops::Load.new(node.properties[:mask])
          op = Ops::Mask.new(input: op, mask_op: mask_op)
        end

        op
      end

      private

      def resolve_width(value, parent)
        return parent if value.nil? || value == :fill
        return value unless value.is_a?(String) && value.end_with?('%')

        return value if parent.nil?
        (parent * (value.to_f / 100.0)).round
      end

      def resolve_height(value, parent)
        resolve_width(value, parent)
      end

      def build_base_op(node)
        case node.source_type
        when :file     then build_load_op(node)
        when :solid    then build_solid_op(node)
        when :text     then build_text_op(node)
        when :gradient then build_gradient_op(node)
        end
      end

      def build_load_op(node)
        w = @width_stack.last
        h = @height_stack.last

        target_w = resolve_width(node.width, w)
        target_h = resolve_height(node.height, h)

        crop = :centre if node.fit == :cover && target_w.is_a?(Numeric) && target_h.is_a?(Numeric)

        if node.trim && target_w.is_a?(Numeric) && target_w < 1000
          target_w *= 2
        end

        Ops::Load.new(node.source, target_width: target_w, target_height: target_h, crop_mode: crop)
      end

      def build_solid_op(node)
        w = resolve_width(node.width, @width_stack.last || 1)
        h = resolve_height(node.height, @height_stack.last || 1)
        w = w.is_a?(Numeric) ? w : 1
        h = h.is_a?(Numeric) ? h : 1
        Ops::Solid.new(color: node.solid, width: w, height: h)
      end

      def build_text_op(node)
        w = resolve_width(node.width, @width_stack.last)
        Ops::Text.new(text: node.text, font: node.font || 'sans', size: node.size || 24, color: node.color || '#000',
                      width: w.is_a?(Numeric) ? w : nil)
      end

      def build_gradient_op(node)
        w = resolve_width(node.width, @width_stack.last || 1)
        h = resolve_height(node.height, @height_stack.last || 1)
        w = w.is_a?(Numeric) ? w : 1
        h = h.is_a?(Numeric) ? h : 1

        Ops::Gradient.new(
          from: node.gradient[:from], to: node.gradient[:to],
          direction: node.gradient[:direction] || :top_bottom,
          width: w, height: h
        )
      end

      def apply_effects(op, effects)
        effects.inject(op) { |o, e| Ops::EffectOp.new(input: o, effect_node: e) }
      end
    end
  end
end