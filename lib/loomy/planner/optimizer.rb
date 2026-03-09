module Loomy
  module Planner
    class Optimizer
      def optimize(op)
        # Traverse the op tree and optimize
        # Usually starts with Pipeline, which has children
        
        if op.is_a?(Ops::Pipeline)
          op.layers.each do |layer_def|
            layer_def[:op] = optimize_tree(layer_def[:op])
          end
          return op
        end
        
        optimize_tree(op)
      end

      private

      def optimize_tree(op)
        # Recursive bottom-up optimization? Or top-down?
        # Let's do recursive first to optimize inputs.
        
        if op.respond_to?(:input) && op.input
          op.input = optimize_tree(op.input)
        end

        # Now apply local rules
        
        # RULE 1: Smart Load (Push Resize into Load)
        # Case: Load -> Resize
        if op.is_a?(Ops::Resize) && op.input.is_a?(Ops::Load)
           # Only push to Load if they are actual numbers
           if op.width.is_a?(Numeric) || op.height.is_a?(Numeric)
             load_op = op.input
             load_op.target_width = op.width
             load_op.target_height = op.height
             load_op.crop_mode = (op.fit == :cover ? :centre : nil)
           end
           
           return op
        end

        # RULE 2: Trim Optimization
        # Case: Load -> Trim -> Resize
        if op.is_a?(Ops::Resize) && op.input.is_a?(Ops::Trim) && op.input.input.is_a?(Ops::Load)
           resize_op = op
           
           if resize_op.width.is_a?(Numeric) && resize_op.width < 1000
             trim_op = resize_op.input
             load_op = trim_op.input
             
             safe_width = (resize_op.width * 2) 
             load_op.target_width = safe_width
             load_op.crop_mode = nil 
           end
        end

        op
      end
    end
  end
end
