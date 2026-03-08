require_relative "base"

module Loomy
  module Ops
    class Pipeline < Base
      attr_reader :layers, :background_width, :background_height

      def initialize(background_width:, background_height:)
        super(input: nil)
        @background_width = background_width
        @background_height = background_height
        @layers = [] # Array of { op: Op, x: int, y: int, blend: symbol }
      end

      def add_layer(op, x, y, blend)
        @layers << { op: op, x: x, y: y, blend: blend }
      end

      def call(context = nil)
        rendered = render_layers(context)
        w, h     = canvas_size(rendered)
        canvas   = transparent_background(w, h)

        return canvas if rendered.empty?

        values = ->(layer) { layer.values_at(:image, :blend, :x, :y) }
        images, modes, xs, ys = rendered.map(&values).transpose
        canvas.composite(images, modes, x: xs, y: ys)
      end

      private

      def render_layers(context)
        @layers.map do |layer|
          {
            image: ensure_srgb(layer[:op].call(context)),
            blend: layer[:blend] || :over,
            x:     layer[:x]     || 0,
            y:     layer[:y]     || 0
          }
        end
      end

      def canvas_size(rendered)
        [
          @background_width  || rendered.map { |l| l[:x] + l[:image].width }.max  || 1,
          @background_height || rendered.map { |l| l[:y] + l[:image].height }.max || 1
        ]
      end

      def transparent_background(w, h)
        Vips::Image
          .black(w, h, bands: 3)
          .copy(interpretation: :srgb)
          .bandjoin(0)
      end

      def ensure_srgb(img)
        return img unless img.bands >= 3 && img.interpretation == :multiband

        img.copy(interpretation: :srgb)
      end
    end
  end
end
