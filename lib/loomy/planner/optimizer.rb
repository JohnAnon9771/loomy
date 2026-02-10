require "loomy/ops/load"
require "loomy/ops/resize"
require "loomy/ops/trim"

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
           # Inject dimensions into Load so it uses thumbnail_image
           load_op = op.input
           load_op.target_width = op.width
           load_op.target_height = op.height
           load_op.crop_mode = (op.fit == :cover ? :centre : nil)
           
           # If the load handles the resize perfectly (e.g. thumbnail),
           # we might remove the Resize op or keep it for fine-tuning.
           # Vips thumbnail is usually good enough.
           
           # For safety, we keep the Resize op because thumbnail might return approximate size
           # unless size: :force is used.
           return op
        end

        # RULE 2: Trim Optimization (The User's Request)
        # Case: Load -> Trim -> Resize
        # If we are resizing down a lot, we should Load(thumb) -> Resize -> Trim (maybe)
        # OR Load(thumb) -> Trim -> Resize.
        
        if op.is_a?(Ops::Resize) && op.input.is_a?(Ops::Trim) && op.input.input.is_a?(Ops::Load)
           resize_op = op
           trim_op = resize_op.input
           load_op = trim_op.input
           
           # Check if it's a huge reduction
           # Since we don't know the image size yet, we can check target size.
           # If target is small (e.g. < 500px), loading full image just to trim is wasteful.
           
           is_small_target = (resize_op.width && resize_op.width < 1000)
           
           if is_small_target
             # Reorder: Load -> Resize(Approx) -> Trim -> Resize(Final)
             # OR simply: Load(Thumbnail with margin) -> Trim -> Resize
             
             # Let's modify the Load to fetch a "safe" larger thumbnail
             # Assuming Trim won't remove more than 50% of the image (heuristic)
             safe_width = (resize_op.width * 2) 
             
             load_op.target_width = safe_width
             # We remove the crop_mode from Load because we need the full content to Trim
             load_op.crop_mode = nil 
             
             # The graph structure Load -> Trim -> Resize remains, 
             # but Load is now much faster because it loads a smaller image.
           end
        end

        op
      end
    end
  end
end
