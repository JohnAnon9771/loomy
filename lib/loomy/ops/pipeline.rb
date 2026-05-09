# frozen_string_literal: true

module Loomy
  module Ops
    class Pipeline < Base
      def initialize(background_width: nil, background_height: nil, dpi: nil)
        super(input: nil)
        @compositor = Compositor.new(background_width: background_width, background_height: background_height)
        @dpi = dpi
      end

      def layers
        @compositor.layers
      end

      def add_layer(op, properties = {})
        return unless op

        @compositor.add_layer(op, properties)
      end

      def call(context = nil)
        prepared = @compositor.prepare(context)
        image = @compositor.render(prepared)

        if @dpi
          image.xres = @dpi.to_f / MM_PER_INCH
          image.yres = @dpi.to_f / MM_PER_INCH
        end

        image
      end

      MM_PER_INCH = 25.4
    end
  end
end
