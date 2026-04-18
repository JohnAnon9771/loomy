module Loomy
  module Ops
    class Pipeline < Base
      def initialize(background_width: nil, background_height: nil)
        super(input: nil)
        @compositor = Compositor.new(background_width: background_width, background_height: background_height)
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
        @compositor.render(prepared)
      end
    end
  end
end
