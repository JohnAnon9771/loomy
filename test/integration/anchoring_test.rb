# frozen_string_literal: true

require_relative '../test_helper'

class AnchoringTest < Minitest::Test
  def test_anchor_bottom_right
    res = Loomy.generate(size: [200, 200]) do
      layer solid: '#f00', width: 50, height: 50, anchor: :bottom_right
    end

    # Square ends at (200, 200), starts at (150, 150)
    assert_equal [255, 0, 0, 255], res.getpoint(175, 175).map(&:to_i)
    assert_equal 0, res.getpoint(149, 149)[3]
  end

  def test_anchor_middle_center
    res = Loomy.generate(size: [300, 300]) do
      layer solid: '#0f0', width: 100, height: 100, anchor: :middle_center
    end

    # (300-100)/2 = 100
    assert_equal [0, 255, 0, 255], res.getpoint(150, 150).map(&:to_i)
    assert_equal 0, res.getpoint(99, 150)[3]
  end

  def test_anchoring_block_usage
    res = Loomy.generate(size: [100, 100]) do
      layer do
        solid '#00f'
        width 20
        height 20
        anchor :bottom_left
      end
    end

    # Bottom-left: x=0, y=100-20=80
    assert_equal [0, 0, 255, 255], res.getpoint(10, 90).map(&:to_i)
    assert_equal 0, res.getpoint(10, 79)[3]
  end
end
