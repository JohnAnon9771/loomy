# frozen_string_literal: true

module Loomy
  module Engine
    class VipsBackend
      def initialize(canvas)
        @canvas = canvas
      end

      def call
        optimized_plan = Planner::Builder.new.build(@canvas)

        context = { source_cache: {} }
        image = optimized_plan.call(context)

        if @canvas.dpi
          dpi = @canvas.dpi.to_f
          image.xres = dpi / 25.4
          image.yres = dpi / 25.4
        end

        image
      end
    end
  end
end
