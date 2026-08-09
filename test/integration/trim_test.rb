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
end
