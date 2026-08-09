# frozen_string_literal: true

require 'test_helper'

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

    canvas = build_canvas do
      layer 'test/assets/base.png' do
        use :test_style
        y 60 # applied after the style, so it wins
      end
    end

    layer = canvas.children.first

    assert_equal 100, layer.x
    assert_equal 60, layer.y
    assert_equal :add, layer.blend_mode
  end

  def test_undefined_style_raises_and_lists_the_known_ones
    Loomy.define_style(:hero) { x 1 }

    error = assert_raises(Loomy::UnknownStyle) do
      build_canvas do
        layer('test/assets/base.png') { use :non_existent }
      end
    end

    assert_match(/non_existent/, error.message)
    assert_match(/hero/, error.message)
  end

  def test_styles_apply_to_containers_too
    Loomy.define_style(:offset_group) { x 25 }

    canvas = build_canvas do
      group do
        use :offset_group
        layer 'test/assets/base.png'
      end
    end

    assert_equal 25, canvas.children.first.x
  end

  private

  def build_canvas(&)
    Loomy::DSL::PipelineBuilder.new({ size: [100, 100] }, &).build
  end
end
