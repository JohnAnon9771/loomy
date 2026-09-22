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

  COPY = 'Selected pieces, in the finish you already know, at a price that will not come round again.'

  # The check #34 asked for: where the ink actually lands against where
  # align/valign promised it would. Layout and render used to disagree on text
  # with a width:, so the ink sat off centre by half the difference.
  def test_wrapped_text_lands_where_alignment_put_it
    assert_ink_centred(text: COPY, width: 600)
  end

  def test_short_text_in_a_wide_box_lands_where_alignment_put_it
    assert_ink_centred(text: 'Sale', width: 600)
  end

  # The renderer only wrapped for an Integer width, so a percentage wrapped in
  # layout and drew as one long line.
  def test_percentage_width_wraps_in_the_render_too
    assert_ink_centred(text: COPY, width: '50%')
  end

  def test_text_without_width_still_lands_where_alignment_put_it
    assert_ink_centred(text: 'Sale')
  end

  private

  def assert_ink_centred(**declaration)
    res = Loomy.generate(size: [900, 400]) do
      layer size: 30, color: '#fff', align: :center, valign: :middle, **declaration
    end
    wrap = { 600 => 600, '50%' => 450, nil => 0 }.fetch(declaration[:width])
    mask = Vips::Image.text(declaration[:text], font: 'sans 30', width: wrap)

    expected = [(900 - mask.width) / 2, (400 - mask.height) / 2, mask.width, mask.height]

    assert_equal expected, res.extract_band(3).find_trim(threshold: 0, background: [0])
  end
end
