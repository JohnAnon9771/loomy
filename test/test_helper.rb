require "loomy"
require "minitest/autorun"
require "vips"
require "fileutils"

module TestHelper
  def self.generate_assets
    FileUtils.mkdir_p("test/assets")
    FileUtils.mkdir_p("test/tmp")

    # Base red image
    unless File.exist?("test/assets/base.png")
      Vips::Image.black(500, 500, bands: 3)
                 .linear([1, 1, 1], [255, 0, 0])
                 .bandjoin(255)
                 .cast(:uchar)
                 .write_to_file("test/assets/base.png")
    end

    # Blue square
    unless File.exist?("test/assets/blue_square.png")
      Vips::Image.black(200, 200, bands: 3)
                 .linear([1, 1, 1], [0, 0, 255])
                 .bandjoin(255)
                 .cast(:uchar)
                 .write_to_file("test/assets/blue_square.png")
    end

    # Grid for displacement
    unless File.exist?("test/assets/grid.png")
       grid = Vips::Image.black(200, 200, bands: 3)
                         .linear([1, 1, 1], [128, 128, 128])
                         .bandjoin(255)
                         .cast(:uchar)
       grid.write_to_file("test/assets/grid.png")
    end
    
    # Displacement map
    unless File.exist?("test/assets/disp_map.png")
       Vips::Image.black(200, 200, bands: 1)
                  .linear([1], [50])
                  .cast(:uchar)
                  .write_to_file("test/assets/disp_map.png")
    end

    # Large assets for integration
    unless File.exist?("test/assets/base_large.png")
      Vips::Image.black(1000, 1000, bands: 3).linear([1,1,1], [100, 100, 100]).bandjoin(255).cast(:uchar).write_to_file("test/assets/base_large.png")
    end

    unless File.exist?("test/assets/overlay_large.png")
      Vips::Image.black(1000, 1000, bands: 3).linear([1,1,1], [200, 200, 200]).bandjoin(128).cast(:uchar).write_to_file("test/assets/overlay_large.png")
    end
  end

  def assert_image_similar(expected_path, actual_image, tolerance: 0.1)
    # If actual_image is a path, load it
    actual = if actual_image.is_a?(String)
      Vips::Image.new_from_file(actual_image)
    else
      actual_image
    end

    unless File.exist?(expected_path)
      # Auto-generate reference if missing (careful in CI)
      FileUtils.mkdir_p(File.dirname(expected_path))
      actual.write_to_file(expected_path)
      return
    end

    expected = Vips::Image.new_from_file(expected_path)
    
    # Ensure same size and bands for comparison
    if expected.width != actual.width || expected.height != actual.height
      flunk "Image dimensions mismatch: expected #{expected.width}x#{expected.height}, got #{actual.width}x#{actual.height}"
    end

    # Calculate Mean Absolute Error (MAE)
    # Convert to float to avoid wrap-around in subtraction
    diff = (expected.cast(:float) - actual.cast(:float)).abs.avg
    
    assert diff <= tolerance, "Image similarity failed. Mean difference: #{diff} (tolerance: #{tolerance})"
  end
end

TestHelper.generate_assets

# Mixin helper to Minitest
class Minitest::Test
  include TestHelper
end
