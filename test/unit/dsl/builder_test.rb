# frozen_string_literal: true

require 'test_helper'
require 'loomy/dsl/pipeline_builder'

class SmartDSLTest < Minitest::Test
  def test_block_attributes
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    builder = Loomy::DSL::CanvasBuilder.new(canvas)

    builder.layer 'test/assets/base.png' do
      x 10
      y 20
      width 50
      height 60
      blend :multiply
      trim true
      fit :cover
    end

    assert_equal 1, canvas.children.size
    layer = canvas.children.first

    assert_equal 10, layer.x, 'Layer x should be 10'
    assert_equal 20, layer.y, 'Layer y should be 20'
    assert_equal 50, layer.width, 'Layer width should be 50'
    assert_equal 60, layer.height, 'Layer height should be 60'
    assert_equal :multiply, layer.blend_mode, 'Layer blend should be :multiply'
    assert_equal true, layer.trim, 'Layer trim should be true'
    assert_equal :cover, layer.fit, 'Layer fit should be :cover'
  end

  def test_mixed_attributes
    # Verify kwargs + block overrides or merges
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    builder = Loomy::DSL::CanvasBuilder.new(canvas)

    # Block should override kwargs if we are simply setting properties on the node object that was created with kwargs.
    # Let's check logic:
    # 1. PipelineBuilder creates node with kwargs.
    # 2. PipelineBuilder calls LayerBuilder.evaluate block
    # 3. LayerBuilder methods set properties.
    # So block overwrites kwargs. This is desired (specific overrides general).

    builder.layer 'test/assets/base.png', x: 5, y: 5 do
      x 15 # Should override
      # y remains 5
    end

    layer = canvas.children.first
    assert_equal 15, layer.x
    assert_equal 5, layer.y
  end
end
