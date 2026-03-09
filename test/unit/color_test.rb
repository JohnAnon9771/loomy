require_relative '../test_helper'

class ColorTest < Minitest::Test
  def test_hex_3_chars
    color = Loomy::Color.new("#f00")
    assert_equal [255, 0, 0, 255], color.rgba
  end

  def test_hex_6_chars
    color = Loomy::Color.new("#00ff00")
    assert_equal [0, 255, 0, 255], color.rgba
  end

  def test_hex_8_chars
    color = Loomy::Color.new("#0000ff80") # 128 in hex is 80
    assert_equal [0, 0, 255, 128], color.rgba
  end

  def test_hex_without_hash
    color = Loomy::Color.new("ff00ff")
    assert_equal [255, 0, 255, 255], color.rgba
  end

  def test_rgb_array
    color = Loomy::Color.new([10, 20, 30])
    assert_equal [10, 20, 30, 255], color.rgba
  end

  def test_rgba_array
    color = Loomy::Color.new([10, 20, 30, 40])
    assert_equal [10, 20, 30, 40], color.rgba
  end

  def test_invalid_input_defaults_to_black
    assert_equal [0, 0, 0, 255], Loomy::Color.new(nil).rgba
    assert_equal [0, 0, 0, 255], Loomy::Color.new("invalid").rgba
    assert_equal [0, 0, 0, 255], Loomy::Color.new("#abcd").rgba # Invalid length
  end

  def test_accessors
    color = Loomy::Color.new("#aabbccdd")
    assert_equal 0xaa, color.r
    assert_equal 0xbb, color.g
    assert_equal 0xcc, color.b
    assert_equal 0xdd, color.a
  end

  def test_to_rgb
    color = Loomy::Color.new("#ff00ff80")
    assert_equal [255, 0, 255], color.to_rgb
  end
end
