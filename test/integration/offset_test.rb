require_relative '../test_helper'

class OffsetTest < Minitest::Test
  def test_offset_with_alignment
    res = Loomy.generate(size: [200, 200]) do
      layer solid: "#fff", width: 20, height: 20, align: :center, offset_x: 50
    end
    
    # (200-20)/2 = 90. + 50 offset = 140.
    assert_equal [255, 255, 255, 255], res.getpoint(150, 10).map(&:to_i)
    assert_equal 0, res.getpoint(100, 10)[3]
  end

  def test_offset_block_usage
    res = Loomy.generate(size: [100, 100]) do
      layer do
        solid "#f00"
        width 10
        height 10
        anchor :top_left
        offset [10, 10]
      end
    end
    
    # top-left is 0,0. + 10,10 offset = 10,10
    assert_equal [255, 0, 0, 255], res.getpoint(15, 15).map(&:to_i)
    assert_equal 0, res.getpoint(5, 5)[3]
  end
end
