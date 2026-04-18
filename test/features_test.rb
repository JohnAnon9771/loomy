# frozen_string_literal: true

require 'test_helper'

class FeaturesTest < Minitest::Test
  def setup
    # Ensure assets are fresh if needed, or use TestHelper assets
  end

  def teardown
    # Clean up
  end

  def test_basic_rendering
    output = 'test_render_basic.png'
    Loomy.render(output, size: [800, 600]) do
      layer 'test/assets/base.png'
    end

    assert File.exist?(output)
    img = Vips::Image.new_from_file(output)
    assert_equal 800, img.width
    assert_equal 600, img.height
    File.delete(output)
  end

  def test_transforms
    output = 'test_render_transforms.png'
    # Test resize and position
    Loomy.render(output, size: [800, 600]) do
      layer 'test/assets/base.png', width: 800, height: 600 # Implicit fill/stretch if logic implies? No, implementation default is contain?
      # Wait, default fit is nil -> 'resize' logic above might default to thumbnail which is contain.

      # Explicit test for cover
      layer 'test/assets/blue_square.png', width: 100, height: 50, fit: :cover, x: 50, y: 50

      # Explicit test for fill/stretch
      layer 'test/assets/base.png', width: 100, height: 50, fit: :fill, x: 200, y: 50
    end

    assert File.exist?(output)
    File.delete(output)
  end

  def test_blend_modes
    output = 'test_render_blend.png'
    Loomy.render(output, size: [500, 500]) do
      layer 'test/assets/base.png' # Red
      layer 'test/assets/blue_square.png', blend: :multiply
    end

    assert File.exist?(output)
    # Visual check logic would require reading pixel at 0,0 and ensuring it is black (Red * Blue = 0)
    img = Vips::Image.new_from_file(output)

    # Check pixel at 0,0. Base is Red (255,0,0). Blue is Blue (0,0,255).
    # Multiply: (255*0)/255 = 0.
    # Result should be Black (0,0,0) (plus alpha)
    pixel = img.getpoint(0, 0)
    # pixel is [r, g, b, a]

    # Tolerance for compression if png? PNG is lossless.
    assert_equal 0, pixel[0], 'Red channel should be 0'
    assert_equal 0, pixel[1], 'Green channel should be 0'
    assert_equal 0, pixel[2], 'Blue channel should be 0'

    File.delete(output)
  end
end
