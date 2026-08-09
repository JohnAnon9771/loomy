# frozen_string_literal: true

module Loomy
  # The opaque extent of an image, as returned by `bounds_of` in the DSL.
  #
  # Lived inside dsl/pipeline_builder.rb, where Zeitwerk could never autoload it:
  # that file is expected to define Loomy::DSL::PipelineBuilder and nothing else,
  # so `require "loomy"; Loomy::Bounds` raised NameError until something happened
  # to load the pipeline builder first.
  Bounds = Data.define(:x, :y, :width, :height)
end
