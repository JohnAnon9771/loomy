# frozen_string_literal: true

module Loomy
  # The opaque extent of an image, as returned by `bounds_of` in the DSL.
  Bounds = Data.define(:x, :y, :width, :height)
end
