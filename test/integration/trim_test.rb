# frozen_string_literal: true

require 'test_helper'

class TrimTest < Minitest::Test
  # trim_test_source.png is a committed fixture: 500x500 transparent with a
  # 100x100 opaque red square centred at 200,200. Its contract is pinned in
  # test/fixtures_test.rb.
  def test_trim_enabled
    reference = 'test/assets/references/trim_enabled.png'

    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/trim_test_source.png', trim: true, x: 0, y: 0
    end

    assert_image_similar(reference, image)

    # Pixel check
    pixel = image.getpoint(0, 0)
    assert_equal [255, 0, 0, 255], pixel.map(&:to_i)
  end

  def test_trim_disabled
    reference = 'test/assets/references/trim_disabled.png'

    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/trim_test_source.png', trim: false, x: 0, y: 0
    end

    assert_image_similar(reference, image)

    pixel = image.getpoint(0, 0)
    assert_equal [0, 0, 0, 0], pixel.map(&:to_i) # Now it should be transparent
  end

  # issue #9, through the whole pipeline. trim_white_on_transparent.png is the
  # same shape as the fixture above in white, which find_trim reads as its own
  # background: this used to measure and render 500x500 and report nothing.
  #
  # No golden. A flat white square gives a reference PNG nothing the size and
  # pixel assertions do not already prove, and every golden is a binary in the
  # suite's visual contract for good.
  def test_a_white_subject_on_transparency_is_trimmed
    image = Loomy.generate do
      layer 'test/assets/trim_white_on_transparent.png', trim: true
    end

    assert_equal [100, 100], [image.width, image.height]
    assert_equal [255, 255, 255, 255], image.getpoint(50, 50).map(&:to_i)
  end

  # The modes are both reachable and they genuinely differ: colour cannot see
  # this subject, so asking for it explicitly leaves the image whole.
  def test_the_colour_mode_leaves_a_white_subject_alone
    image = Loomy.generate do
      layer 'test/assets/trim_white_on_transparent.png', trim: :color
    end

    assert_equal [500, 500], [image.width, image.height]
  end

  # The scan is cached per source, and now per mode as well. One composition
  # asking for both has to get both answers, not whichever it asked for first.
  def test_one_source_can_be_trimmed_both_ways_in_one_composition
    source = 'test/assets/trim_white_on_transparent.png'

    image = Loomy.generate(size: [600, 600]) do
      layer source, trim: :alpha, x: 0, y: 0
      layer source, trim: :color, x: 100, y: 100
    end

    # The colour layer was not trimmed, so it still reaches 500px from x: 100.
    assert_equal [600, 600], [image.width, image.height]
    assert_equal [255, 255, 255, 255], image.getpoint(50, 50).map(&:to_i)
    assert_equal [255, 255, 255, 255], image.getpoint(350, 350).map(&:to_i)
  end
end
