# frozen_string_literal: true

module Loomy
  module Ops
    class Mask < Base
      def initialize(input:, mask:, method: :dest_in)
        super(input: input)
        @mask_source = mask
        @method = method
      end

      def call(context = nil)
        img = @input.call(context)
        mask = load_mask(img)

        img.composite(mask, @method)
      end

      private

      def load_mask(img)
        mask = Vips::Image.new_from_file(@mask_source)

        if mask.width != img.width || mask.height != img.height
          mask = mask.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
        end

        mask = expand_mask_bands(mask, img) if mask.bands < img.bands

        mask
      end

      def expand_mask_bands(mask, img)
        return mask if mask.bands >= img.bands

        target_bands = img.bands
        missing = target_bands - mask.bands

        missing.times { mask = mask.bandjoin(mask) }
        mask
      end
    end
  end
end
