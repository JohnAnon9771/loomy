module Loomy
  module Ops
    class Compositor
      attr_reader :layers, :background_width, :background_height

      def initialize(background_width: nil, background_height: nil)
        @layers = []
        @background_width  = background_width
        @background_height = background_height
      end

      def add_layer(op, properties = {})
        @layers << Layer.new(op, properties)
      end

      def prepare(context)
        @layers.map { |l| l.prepare(context) }
      end

      def render(prepared_layers)
        w, h = canvas_size(prepared_layers)
        return transparent_background(w, h) if prepared_layers.empty?

        images, modes, xs, ys = prepared_layers.map { |l| l.resolve(w, h) }.transpose
        transparent_background(w, h).composite(images, modes, x: xs, y: ys)
      end

      def canvas_size(prepared)
        [
          background_width  || prepared.map(&:max_x).max || 1,
          background_height || prepared.map(&:max_y).max || 1
        ]
      end

      private

      def transparent_background(w, h)
        Vips::Image.black(w, h, bands: 3).copy(interpretation: :srgb).bandjoin(0)
      end
    end
  end
end
