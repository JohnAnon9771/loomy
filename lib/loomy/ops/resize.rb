require_relative "base"

module Loomy
  module Ops
    class Resize < Base
      attr_reader :width, :height, :fit

      def initialize(input:, width:, height:, fit: :contain)
        super(input: input)
        @width = width
        @height = height
        @fit = fit
      end

      def call(context = nil)
        img = @input.call(context)
        return img if @width.nil? && @height.nil?

        target_w = @width || img.width
        target_h = @height || img.height

        return img if img.width == target_w && img.height == target_h

        if @fit == :fill
          scale_x = target_w.to_f / img.width
          scale_y = target_h.to_f / img.height
          img.resize(scale_x, vscale: scale_y)
        elsif @fit == :cover
          img.thumbnail_image(target_w, height: target_h, size: :both, crop: :centre)
        else
          img.thumbnail_image(target_w, height: target_h, size: :both)
        end
      end
    end
  end
end
