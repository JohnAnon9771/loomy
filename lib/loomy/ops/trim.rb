module Loomy
  module Ops
    class Trim < Base
      attr_reader :threshold

      def initialize(input:, threshold: 10)
        super(input: input)
        @threshold = threshold
      end

      def call(context = nil)
        img = @input.call(context)
        
        # Trim requires a pixel scan. It is eager.
        left, top, w, h = img.find_trim(threshold: @threshold)
        
        if w > 0 && h > 0
          img.crop(left, top, w, h)
        else
          img
        end
      end
    end
  end
end
