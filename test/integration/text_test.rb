# frozen_string_literal: true

require_relative '../test_helper'

class TextTest < Minitest::Test
  def test_text_basic
    res = Loomy.generate(size: [400, 100]) do
      layer text: 'Loomy', size: 50, color: '#0000ff'
    end

    assert res.width.positive?
    assert res.height.positive?
    assert_equal 4, res.bands
    # Max of blue band should be 255
    assert_equal 255, res.extract_band(2).max
  end

  def test_text_block_usage
    res = Loomy.generate(size: [500, 200]) do
      layer do
        text 'Dynamic Title'
        font 'sans-serif'
        size 60
        color [255, 0, 0] # Red
        x 50
        y 50
      end
    end

    assert res.width.positive?
    assert_equal 4, res.bands
    # Max of red band should be 255
    assert_equal 255, res.extract_band(0).max
  end
end
