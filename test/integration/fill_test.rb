# frozen_string_literal: true

require_relative '../test_helper'

class FillTest < Minitest::Test
  def test_fill_width
    res = Loomy.generate(size: [300, 100]) do
      layer solid: '#0f0', width: :fill, height: 50
    end

    assert_equal 300, res.width
    # Entire width should be green
    assert_equal [0, 255, 0, 255], res.getpoint(0, 25).map(&:to_i)
    assert_equal [0, 255, 0, 255], res.getpoint(299, 25).map(&:to_i)
  end

  def test_fill_both_axes
    res = Loomy.generate(size: [200, 200]) do
      layer solid: '#f0f', width: :fill, height: :fill
    end

    assert_equal [255, 0, 255, 255], res.getpoint(0, 0).map(&:to_i)
    assert_equal [255, 0, 255, 255], res.getpoint(199, 199).map(&:to_i)
  end

  def test_fill_block_usage
    res = Loomy.generate(size: [100, 100]) do
      layer do
        solid '#fff'
        width :fill
        height 10
        valign :bottom
      end
    end

    assert_equal [255, 255, 255, 255], res.getpoint(50, 95).map(&:to_i)
    assert_equal 0, res.getpoint(50, 85)[3]
  end
end
