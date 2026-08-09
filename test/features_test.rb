# frozen_string_literal: true

require 'test_helper'

class FeaturesTest < Minitest::Test
  def test_basic_rendering
    output = tmp_path('render_basic.png')

    Loomy.render(output, size: [800, 600]) do
      layer 'test/assets/base.png'
    end

    image = Vips::Image.new_from_file(output)

    assert_equal [800, 600], [image.width, image.height]
  end

  # The default fit contains, so a 500x500 source asked for 800x600 comes out
  # 600x600 rather than stretched.
  def test_default_fit_preserves_aspect_ratio
    image = Loomy.generate(size: [800, 600]) do
      layer 'test/assets/base.png', width: 800, height: 600
    end

    assert_equal 0, image.getpoint(700, 300)[3], 'the contained layer should not reach the right edge'
  end

  def test_cover_fills_the_requested_box
    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/blue_square.png', width: 100, height: 50, fit: :cover, x: 0, y: 0
    end

    assert_equal [0, 0, 255, 255], image.getpoint(99, 49).map(&:to_i)
    assert_equal 0, image.getpoint(101, 49)[3]
  end

  def test_fill_stretches_to_the_requested_box
    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/blue_square.png', width: 100, height: 50, fit: :fill, x: 0, y: 0
    end

    assert_equal [0, 0, 255, 255], image.getpoint(99, 49).map(&:to_i)
    assert_equal 0, image.getpoint(99, 51)[3]
  end

  def test_blend_modes
    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/base.png' # red
      layer 'test/assets/blue_square.png', blend: :multiply
    end

    # Red (255,0,0) multiplied by blue (0,0,255) is black on every channel.
    assert_equal [0, 0, 0], image.getpoint(0, 0).map(&:to_i).first(3)
  end
end
