# frozen_string_literal: true

require_relative '../test_helper'

class ColorTest < Minitest::Test
  def test_hex_3_chars
    color = Loomy::Color.new('#f00')
    assert_equal [255, 0, 0, 255], color.rgba
  end

  def test_hex_6_chars
    color = Loomy::Color.new('#00ff00')
    assert_equal [0, 255, 0, 255], color.rgba
  end

  def test_hex_8_chars
    color = Loomy::Color.new('#0000ff80') # 128 in hex is 80
    assert_equal [0, 0, 255, 128], color.rgba
  end

  def test_hex_without_hash
    color = Loomy::Color.new('ff00ff')
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

  # A typo in a colour must fail, not render as a plausible-looking result.
  def test_invalid_input_raises
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new(nil).rgba }
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new('invalid').rgba }
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new('#abcd').rgba } # invalid length
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new('#zzz').rgba }  # right length, not hex
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new([1, 2]).rgba }  # too few channels
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new([0, 0, 300]).rgba } # out of range
    assert_raises(Loomy::InvalidColor) { Loomy::Color.new(:red).rgba } # named colours unsupported
  end

  def test_invalid_color_message_lists_accepted_forms
    error = assert_raises(Loomy::InvalidColor) { Loomy::Color.new('nope').rgba }

    assert_match(/#rrggbbaa/, error.message)
    assert_equal 'nope', error.value
  end

  def test_error_hierarchy
    assert_operator Loomy::InvalidColor, :<, Loomy::Error
  end

  def test_accessors
    color = Loomy::Color.new('#aabbccdd')
    assert_equal 0xaa, color.r
    assert_equal 0xbb, color.g
    assert_equal 0xcc, color.b
    assert_equal 0xdd, color.a
  end

  def test_to_rgb
    color = Loomy::Color.new('#ff00ff80')
    assert_equal [255, 0, 255], color.to_rgb
  end
end
