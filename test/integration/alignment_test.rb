require_relative '../test_helper'

class AlignmentTest < Minitest::Test
  def test_horizontal_alignment_center
    res = Loomy.generate(size: [200, 100]) do
      layer solid: "#00f", width: 50, height: 50, align: :center
    end
    
    # (200 - 50) / 2 = 75
    # Since y is default 0, the blue square is at (75, 0)
    assert_equal [0, 0, 255, 255], res.getpoint(75, 0).map(&:to_i)
    assert_equal [0, 0, 255, 255], res.getpoint(124, 49).map(&:to_i)
    assert_equal 0, res.getpoint(74, 0)[3]
  end

  def test_vertical_alignment_middle
    res = Loomy.generate(size: [100, 200]) do
      layer solid: "#00f", width: 50, height: 50, valign: :middle
    end
    
    # (200 - 50) / 2 = 75
    # Since x is default 0, the blue square is at (0, 75)
    assert_equal [0, 0, 255, 255], res.getpoint(0, 75).map(&:to_i)
    assert_equal [0, 0, 255, 255], res.getpoint(49, 124).map(&:to_i)
    assert_equal 0, res.getpoint(0, 74)[3]
  end

  def test_alignment_block_usage
    res = Loomy.generate(size: [200, 200]) do
      layer do
        solid "#f00"
        width 100
        height 100
        align :center
        valign :middle
      end
    end
    
    # (200-100)/2 = 50. Square at (50, 50) to (150, 150)
    assert_equal [255, 0, 0, 255], res.getpoint(100, 100).map(&:to_i)
    assert_equal 0, res.getpoint(0, 0)[3]
  end
end
