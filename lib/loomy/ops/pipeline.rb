require_relative "base"
require_relative "../color"

module Loomy
  module Ops
    class Pipeline < Base
      attr_reader :background_width, :background_height

      def initialize(background_width:, background_height:)
        super(input: nil)
        @background_width  = background_width
        @background_height = background_height
        @layers = []
      end

      def add_layer(op, properties = {}) = @layers << Layer.new(op, properties)

      def call(context = nil)
        prepared = @layers.map { |l| l.prepare(context) }
        w, h     = canvas_size(prepared)
        
        return transparent_background(w, h) if prepared.empty?

        images, modes, xs, ys = prepared.map { |l| l.resolve(w, h) }.transpose
        transparent_background(w, h).composite(images, modes, x: xs, y: ys)
      end

      private

      def canvas_size(layers) = [
        @background_width  || layers.map(&:max_x).max || 1,
        @background_height || layers.map(&:max_y).max || 1
      ]

      def transparent_background(w, h)
        Vips::Image.black(w, h, bands: 3).copy(interpretation: :srgb).bandjoin(0)
      end
    end
  end
end
