require "loomy/ast/visitor"
require "loomy/ops/base"
require "loomy/ops/load"
require "loomy/ops/trim"
require "loomy/ops/resize"
require "loomy/ops/effect_op"
require "loomy/ops/pipeline"

module Loomy
  module Planner
    class Builder < AST::Visitor
      def initialize
        @width_stack = []
        @height_stack = []
      end

      def build(canvas)
        @width_stack = [canvas.width]
        @height_stack = [canvas.height]
        visit(canvas)
      end

      def visit_canvas(node)
        pipeline = Ops::Pipeline.new(
          background_width: node.width,
          background_height: node.height
        )

        node.children.each do |layer|
          op_tree = visit(layer)

          if op_tree
            pipeline.add_layer(
              op_tree,
              layer.x || 0,
              layer.y || 0,
              layer.blend_mode || :over
            )
          end
        end

        pipeline
      end

      def visit_group(node)
        # 1. Create sub-pipeline for the group
        # If group width/height are not set, it might be tricky for 'Pipeline' 
        # which creates a black background.
        # For now, we assume groups have a size or we use the parent size.
        
        parent_w = @width_stack.last
        parent_h = @height_stack.last
        
        @width_stack.push(node.width || parent_w)
        @height_stack.push(node.height || parent_h)

        pipeline = Ops::Pipeline.new(
          background_width: node.width || parent_w,
          background_height: node.height || parent_h
        )

        node.children.each do |child|
          op_tree = visit(child)
          if op_tree
             pipeline.add_layer(
               op_tree,
               child.x || 0,
               child.y || 0,
               child.blend_mode || :over
             )
          end
        end

        @width_stack.pop
        @height_stack.pop

        op = pipeline

        # Apply group-level effects
        node.effects.each do |effect|
          op = Ops::EffectOp.new(input: op, effect_node: effect)
        end

        op
      end

      def visit_layer(node)
        # 1. Base Op: Load
        # Apply "Smart Load" optimization eagerly
        load_target_w = nil
        load_target_h = nil
        load_crop = nil

        # If it's a simple resize (no trim before it), we can push to Load
        if !node.trim && (node.width || node.height)
          load_target_w = node.width
          load_target_h = node.height
          load_crop = (node.fit == :cover ? :centre : nil)
        elsif node.trim && (node.width && node.width < 1000)
          # Trim optimization: Load a safe thumbnail first
          load_target_w = node.width * 2
        end

        op = Ops::Load.new(
          node.source,
          target_width: load_target_w,
          target_height: load_target_h,
          crop_mode: load_crop
        )

        # 2. Trim
        op = Ops::Trim.new(input: op) if node.trim

        # 3. Resize
        if node.width || node.height
          op = Ops::Resize.new(
            input: op,
            width: node.width,
            height: node.height,
            fit: node.fit
          )
        end

        # 4. Effects (Applied after resize for performance)
        node.effects.each do |effect|
          op = Ops::EffectOp.new(input: op, effect_node: effect)
        end

        op
      end
    end
  end
end
