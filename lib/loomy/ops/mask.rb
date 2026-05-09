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

        # Resize mask to match image dimensions
        if mask.width != img.width || mask.height != img.height
          mask = mask.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
        end

        mask
      end
    end
  end
end
