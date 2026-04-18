# frozen_string_literal: true

require 'test_helper'

class ExtractBoundsTest < Minitest::Test
  def test_bounds_of_returns_correct_coordinates
    result = nil
    Loomy.generate(size: [500, 500]) do
      result = bounds_of 'test/assets/trim_test_source.png'
    end

    assert_equal 200, result.x
    assert_equal 200, result.y
    assert_equal 100, result.width
    assert_equal 100, result.height
  end

  def test_bounds_of_is_simple_struct
    result = nil
    Loomy.generate(size: [500, 500]) do
      result = bounds_of 'test/assets/trim_test_source.png'
    end

    assert_respond_to result, :x
    assert_respond_to result, :y
    assert_respond_to result, :width
    assert_respond_to result, :height
  end
end
