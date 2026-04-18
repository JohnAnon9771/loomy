module Loomy
  module Planner
    class Optimizer
      def optimize(op)
        return op unless op

        if op.is_a?(Ops::Pipeline)
          op.layers.each do |layer_def|
            layer_def.op = optimize_tree(layer_def.op)
          end
          return op
        end

        optimize_tree(op)
      end

      private

      def optimize_tree(op)
        return op unless op

        optimized_input = op.input ? optimize_tree(op.input) : nil

        if op.is_a?(Ops::Resize) && op.input.is_a?(Ops::Load)
          return optimize_resize_into_load(op, optimized_input)
        end

        if op.is_a?(Ops::Resize) && op.input.is_a?(Ops::Trim) && op.input.input.is_a?(Ops::Load)
          return optimize_trim_resize(op, optimized_input)
        end

        op.input = optimized_input
        op
      end

      def optimize_resize_into_load(resize_op, load_op)
        return resize_op unless load_op.is_a?(Ops::Load)

        unless resize_op.width.is_a?(Numeric) || resize_op.height.is_a?(Numeric)
          resize_op.input = load_op
          return resize_op
        end

        Ops::Load.new(
          load_op.path,
          target_width: resize_op.width,
          target_height: resize_op.height,
          crop_mode: resize_op.fit == :cover ? :centre : nil
        )
      end

      def optimize_trim_resize(resize_op, trim_op)
        return resize_op unless trim_op.is_a?(Ops::Trim)

        load_op = trim_op.input
        return resize_op unless load_op.is_a?(Ops::Load)

        unless resize_op.width.is_a?(Numeric) && resize_op.width < 1000
          resize_op.input = trim_op
          return resize_op
        end

        Ops::Load.new(
          load_op.path,
          target_width: resize_op.width * 2,
          target_height: nil,
          crop_mode: nil
        )
      end
    end
  end
end