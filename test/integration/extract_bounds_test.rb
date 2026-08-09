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

  # bounds_of exists so a caller can position against what `trim: true` crops
  # to. The two have to reach the same numbers by construction, not by both
  # happening to spell the same threshold.
  def test_bounds_of_matches_what_trim_crops_to
    source = 'test/assets/trim_test_source.png'
    result = nil

    image = Loomy.generate do
      result = bounds_of source
      layer source, trim: true
    end

    assert_equal [100, 100], [result.width, result.height]
    assert_equal [image.width, image.height], [result.width, result.height]
  end

  def test_bounds_of_a_missing_source_names_the_file
    error = assert_raises(Loomy::SourceNotFound) do
      Loomy.generate(size: [10, 10]) { bounds_of 'test/assets/does_not_exist.png' }
    end

    assert_match(/does_not_exist\.png/, error.message)
  end
end
