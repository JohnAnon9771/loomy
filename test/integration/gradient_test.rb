require_relative '../test_helper'

class GradientTest < Minitest::Test
  def test_gradient_top_bottom
    res = Loomy.generate(size: [100, 100]) do
      layer gradient: { from: "#ff0000", to: "#0000ff", direction: :top_bottom }
    end
    
    # Top should be red, bottom should be blue
    top_pixel = res.getpoint(50, 0).map(&:to_i)
    bottom_pixel = res.getpoint(50, 99).map(&:to_i)
    
    # Check with tolerance
    assert (top_pixel[0] - 255).abs < 5
    assert top_pixel[2] < 5
    
    assert bottom_pixel[0] < 5
    assert (bottom_pixel[2] - 255).abs < 5
  end

  def test_gradient_left_right
    res = Loomy.generate(size: [100, 100]) do
      layer gradient: { from: "#ff0000", to: "#0000ff", direction: :left_right }
    end
    
    # Left should be red, right should be blue
    left_pixel = res.getpoint(0, 50).map(&:to_i)
    right_pixel = res.getpoint(99, 50).map(&:to_i)
    
    # Check with tolerance
    assert (left_pixel[0] - 255).abs < 5
    assert (right_pixel[2] - 255).abs < 5
  end

  def test_gradient_block_usage
    res = Loomy.generate(size: [200, 200]) do
      layer do
        gradient from: "#000", to: "#fff"
        width 200
        height 200
      end
    end
    
    # Check black to white
    assert_equal 0, res.getpoint(100, 0)[0].to_i
    assert (res.getpoint(100, 199)[0].to_i - 255).abs < 5
  end
end
