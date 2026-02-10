module Loomy
  module Ops
    class Base
      attr_accessor :input

      def initialize(input: nil)
        @input = input
      end

      def call(context = nil)
        raise NotImplementedError
      end
    end
  end
end
