# frozen_string_literal: true

module Loomy
  module Ops
    class DpiMetadata < Base
      MM_PER_INCH = 25.4

      def initialize(input:, dpi:)
        super(input: input)
        @dpi = dpi
      end

      def call(context = nil)
        image = @input.call(context)

        if @dpi
          dpi = @dpi.to_f
          image.xres = dpi / MM_PER_INCH
          image.yres = dpi / MM_PER_INCH
        end

        image
      end
    end
  end
end