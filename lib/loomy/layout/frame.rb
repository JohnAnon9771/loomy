# frozen_string_literal: true

module Loomy
  module Layout
    # Where a node ends up and how big it renders.
    #
    # width/height are the *actual* pixel size the node will occupy, not the
    # size that was asked for: a 2:1 image declared `width: 100, height: 100`
    # with the default contain fit measures 100x50, and placement has to use
    # 100x50 or centring comes out wrong.
    Frame = Data.define(:x, :y, :width, :height) do
      def right  = x + width
      def bottom = y + height
    end
  end
end
