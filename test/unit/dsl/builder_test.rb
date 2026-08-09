# frozen_string_literal: true

require 'test_helper'

class SmartDSLTest < Minitest::Test
  # Deliberately no manual require: both constants have to be autoloadable from
  # `require "loomy"` alone.
  def test_canvas_builder_is_autoloadable
    assert_kind_of Class, Loomy::DSL::CanvasBuilder
    assert_kind_of Class, Loomy::Bounds
  end

  def test_block_attributes
    canvas = build_canvas do
      layer 'test/assets/base.png' do
        x 10
        y 20
        width 50
        height 60
        blend :multiply
        trim true
        fit :cover
      end
    end

    assert_equal 1, canvas.children.size
    layer = canvas.children.first

    assert_equal 10, layer.x
    assert_equal 20, layer.y
    assert_equal 50, layer.width
    assert_equal 60, layer.height
    assert_equal :multiply, layer.blend_mode
    assert layer.trim
    assert_equal :cover, layer.fit
  end

  def test_block_overrides_keyword_arguments
    canvas = build_canvas do
      layer 'test/assets/base.png', x: 5, y: 5 do
        x 15
      end
    end

    layer = canvas.children.first

    assert_equal 15, layer.x
    assert_equal 5, layer.y
  end

  # A layer is a leaf: nesting must be rejected, not silently dropped.
  def test_nesting_inside_a_layer_is_rejected
    error = assert_raises(Loomy::UnknownProperty) do
      build_canvas do
        layer 'test/assets/base.png' do
          layer 'test/assets/blue_square.png'
        end
      end
    end

    assert_match(/layer/, error.message)
  end

  # Source properties are meaningless on a group and must not be accepted.
  def test_source_properties_are_rejected_on_a_group
    assert_raises(Loomy::UnknownProperty) do
      build_canvas do
        group x: 10 do
          solid '#f00'
        end
      end
    end
  end

  def test_unknown_property_message_lists_what_is_available
    error = assert_raises(Loomy::UnknownProperty) do
      build_canvas { layer('test/assets/base.png') { widht 10 } }
    end

    assert_match(/widht/, error.message)
    assert_match(/width/, error.message)
  end

  def test_containers_still_nest
    canvas = build_canvas do
      group x: 10 do
        vstack spacing: 5 do
          layer 'test/assets/base.png'
        end
      end
    end

    group = canvas.children.first
    stack = group.children.first

    assert_instance_of Loomy::AST::Group, group
    assert_instance_of Loomy::AST::Stack, stack
    assert_equal :vertical, stack.direction
    assert_equal 1, stack.children.size
  end

  private

  def build_canvas(&)
    Loomy::DSL::PipelineBuilder.new({ size: [100, 100] }, &).build
  end
end
