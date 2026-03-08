require_relative '../test_helper'

class DynamicSizeTest < Minitest::Test
  def test_canvas_with_dynamic_size
    # blue_square is actually 200x200
    source = File.expand_path('../assets/blue_square.png', __dir__)
    
    # No size specified
    res = Loomy.generate do
      layer source
    end
    
    assert_equal 200, res.width
    assert_equal 200, res.height
    assert_equal 4, res.bands # 4 bands (RGBA)
  end

  def test_multiple_layers_dynamic_size
    source = File.expand_path('../assets/blue_square.png', __dir__)
    
    res = Loomy.generate do
      layer source, x: 10, y: 10
      layer source, x: 100, y: 100
    end
    
    # Layer 1 ends at 10+200=210, 10+200=210
    # Layer 2 ends at 100+200=300, 100+200=300
    assert_equal 300, res.width
    assert_equal 300, res.height
    assert_equal 4, res.bands
  end

  def test_group_with_dynamic_size
    source = File.expand_path('../assets/blue_square.png', __dir__)
    
    res = Loomy.generate do
      group x: 10, y: 10 do
        layer source # 200x200
      end
    end
    
    # Group size should be 200x200
    # Canvas size should be 10 (offset) + 200 (group width) = 210
    assert_equal 210, res.width
    assert_equal 210, res.height
    assert_equal 4, res.bands
  end

  def test_canvas_with_actual_trim_dynamic_size
    # trim_test_source is 500x500 with a 100x100 red square in the middle
    source = File.expand_path('../assets/trim_test_source.png', __dir__)
    
    res = Loomy.generate do
      layer source, trim: true
    end
    
    # It should be 100x100
    assert_equal 100, res.width
    assert_equal 100, res.height
    assert_equal 4, res.bands
    
    # Check color
    assert_equal [255, 0, 0, 255], res.getpoint(0, 0)
  end

  def test_canvas_dynamic_size_is_always_transparent
    source = File.expand_path('../assets/blue_square.png', __dir__)
    
    res = Loomy.generate do
      layer source, x: 10, y: 10
    end
    
    # Top-left (0,0) should be transparent because blue square is at (10,10)
    pixel = res.getpoint(0, 0)
    assert_equal 0, pixel[3] # Alpha should be 0
  end
end
