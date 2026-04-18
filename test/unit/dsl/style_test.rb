# frozen_string_literal: true

require 'test_helper'
require 'loomy/dsl/pipeline_builder'

class StyleTest < Minitest::Test
  def setup
    Loomy.styles.clear
  end

  def test_define_and_use_style
    Loomy.define_style :test_style do
      x 100
      y 50
      blend :add
    end

    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    builder = Loomy::DSL::CanvasBuilder.new(canvas)

    builder.layer 'test/assets/base.png' do
      use :test_style
      y 60 # Override
    end

    layer = canvas.children.first
    assert_equal 100, layer.x
    assert_equal 60, layer.y # Overridden
    assert_equal :add, layer.blend_mode
  end

  def test_undefined_style
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    builder = Loomy::DSL::CanvasBuilder.new(canvas)

    assert_raises ArgumentError do
      builder.layer 'test/assets/base.png' do
        use :non_existent
      end
    end
  end
end
