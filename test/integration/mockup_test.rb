# frozen_string_literal: true

require 'test_helper'

class MockupIntegrationTest < Minitest::Test
  def setup
    @output_path = 'test/tmp/mockup_result.png'
    @reference_path = 'test/assets/references/mockup_result.png'
    FileUtils.mkdir_p('test/tmp')
  end

  def test_full_mockup_pipeline
    image = Loomy.generate(size: [1000, 1000]) do
      # 1. Base: Template
      layer 'test/assets/base_large.png'

      # 2. Artwork with effects inside a group
      group x: 100, y: 100, width: 400, height: 400 do
        layer 'test/assets/blue_square.png' do
          fit :cover
        end

        # Apply distortion using the template as map
        displace map: 'test/assets/base_large.png', scale: 15

        # Color adjustment
        adjust_color brightness: 1.1, contrast: 0.9
      end

      # 3. Final mask
      layer 'test/assets/overlay_large.png' do
        blend :dest_in
      end
    end

    assert_image_similar(@reference_path, image)
    assert_equal 1000, image.width
    assert_equal 1000, image.height
  end
end
