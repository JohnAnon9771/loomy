# frozen_string_literal: true

module Loomy
  module Engine
    class VipsBackend
      MM_PER_INCH = 25.4

      def initialize(canvas)
        @canvas = canvas
      end

      def call
        plan = Planner::Builder.new.build(@canvas)
        plan = Planner::Optimizer.new.optimize(plan)
        context = { source_cache: {} }
        image = plan.call(context)

        if @canvas.dpi
          dpi = @canvas.dpi.to_f
          image.xres = dpi / MM_PER_INCH
          image.yres = dpi / MM_PER_INCH
        end

        image
      end
    end
  end
end
