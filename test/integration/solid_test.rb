# frozen_string_literal: true

require_relative '../test_helper'

class SolidTest < Minitest::Test
  def test_solid_color_hex
    res = Loomy.generate(size: [100, 100]) do
      layer solid: '#ff0000'
    end

    assert_equal [255, 0, 0, 255], res.getpoint(50, 50).map(&:to_i)
  end

  def test_solid_color_array
    res = Loomy.generate(size: [100, 100]) do
      layer solid: [0, 255, 0]
    end

    assert_equal [0, 255, 0, 255], res.getpoint(50, 50).map(&:to_i)
  end

  def test_solid_color_with_alpha
    res = Loomy.generate(size: [100, 100]) do
      layer solid: '#ff000080' # 50% opacity
    end

    pixel = res.getpoint(50, 50).map(&:to_i)
    assert_equal 255, pixel[0]
    assert_equal 128, pixel[3]
  end

  def test_solid_block_usage
    res = Loomy.generate(size: [200, 200]) do
      layer do
        solid '#0000ff'
        width 100
        height 100
        x 50
        y 50
      end
    end

    assert_equal 200, res.width
    # Outside square should be transparent
    assert_equal 0, res.getpoint(0, 0)[3]
    # Inside square should be blue
    assert_equal [0, 0, 255, 255], res.getpoint(100, 100).map(&:to_i)
  end
end
