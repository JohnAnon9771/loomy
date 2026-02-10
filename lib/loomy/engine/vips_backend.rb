require "vips"
require "loomy/planner/builder"

module Loomy
  module Engine
    class VipsBackend
      def initialize(canvas)
        @canvas = canvas
      end

      def call
        optimized_plan = Planner::Builder.new.build(@canvas)

        context = { source_cache: {} }
        optimized_plan.call(context)
      end
    end
  end
end
