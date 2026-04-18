module Loomy
  module Engine
    class VipsBackend
      def initialize(canvas)
        @canvas = canvas
      end

      def call
        plan = Planner::Builder.new.build(@canvas)
        plan = Planner::Optimizer.new.optimize(plan)
        context = { source_cache: {} }
        plan.call(context)
      end
    end
  end
end
