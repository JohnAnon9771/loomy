require "test_helper"

class TrimTest < Minitest::Test
  def setup
    # Create an image with a central red square and transparent borders
    # 500x500 image, 100x100 red square in middle
    @trim_source = "test/assets/trim_test_source.png"
    
    # Red square 100x100
    square = Vips::Image.black(100, 100, bands: 3).linear([1, 1, 1], [255, 0, 0]).bandjoin(255)
    
    # Embed square in center
    final = square.embed(200, 200, 500, 500, extend: :background, background: [0, 0, 0, 0])
    final.write_to_file(@trim_source)
  end

  def test_trim_enabled
    reference = "test/assets/references/trim_enabled.png"
    
    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/trim_test_source.png", trim: true, x: 0, y: 0
    end
    
    assert_image_similar(reference, image)
    
    # Pixel check for extra confidence
    pixel = image.getpoint(0, 0)
    assert_equal [255, 0, 0, 255], pixel
  end

  def test_trim_disabled
    reference = "test/assets/references/trim_disabled.png"

    image = Loomy.generate(size: [200, 200]) do
      layer "test/assets/trim_test_source.png", trim: false, x: 0, y: 0
    end
    
    assert_image_similar(reference, image)
    
    # Untrimmed image has transparent border at 0,0, composited over black background
    pixel = image.getpoint(0, 0)
    assert_equal [0, 0, 0, 255], pixel
  end
end