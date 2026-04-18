# frozen_string_literal: true

module Loomy
  module Ops
    class Mask < Base
      def initialize(input:, mask_op:, method: :dest_in)
        super(input: input)
        @mask_op = mask_op
        @method = method
      end

      def call(context = nil)
        img = @input.call(context)
        mask = @mask_op.call(context)

        mask = mask.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)

        mask = ensure_bands_match(img, mask)

        img.composite(mask, @method)
      end

      private

      def ensure_bands_match(img, mask)
        if mask.bands == 1 && img.bands >= 3
          mask = mask.bandjoin(mask, mask) if img.bands >= 3
          mask = mask.bandjoin(mask) if img.bands == 4 && mask.bands < 4
        end
        mask
      end
    end
  end
end
