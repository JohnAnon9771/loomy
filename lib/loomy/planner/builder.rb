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
        pw, ph = @width_stack.last, @height_stack.last

        @width_stack.push(node.width  || pw)
        @height_stack.push(node.height || ph)

        pipeline = Ops::Pipeline.new(
          background_width:  node.width  || pw,
          background_height: node.height || ph
        )

        node.children.each { |c| pipeline.add_layer(visit(c), c.properties) if c }

        @width_stack.pop
        @height_stack.pop

        apply_effects(pipeline, node.effects)
      end

      def visit_layer(node)
        op = build_base_op(node)
        op = Ops::Trim.new(input: op) if node.trim && node.source_type == :file

        # We only apply Resize here for static numeric targets.
        # Dynamic axes (nil, :fill, strings) are deferred to Pipeline.
        if node.width.is_a?(Numeric) || node.height.is_a?(Numeric)
          op = Ops::Resize.new(
            input:  op,
            width:  node.width.is_a?(Numeric)  ? node.width  : nil,
            height: node.height.is_a?(Numeric) ? node.height : nil,
            fit:    node.fit
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
        w, h = node.width, node.height

        # Optimization: push fixed numeric sizes into Load
        if !node.trim && w.is_a?(Numeric)
          target_w, target_h = w, h
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
        Ops::Text.new(text: node.text, font: node.font || "sans", size: node.size || 24, color: node.color || "#000", width: w)
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
    end
  end
end
