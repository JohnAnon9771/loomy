# frozen_string_literal: true

require 'test_helper'

class MaskIntegrationTest < Minitest::Test
  def setup
    @output_path = 'test/tmp/mask_result.png'
    FileUtils.mkdir_p('test/tmp')
  end

  def test_explicit_mask_clipping
    reference = 'test/assets/references/mask_basic.png'

    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/blue_square.png', x: 100, y: 100, width: 300, height: 300 do
        mask 'test/assets/overlay.png'
      end
    end

    assert_image_similar(reference, image)
  end

  def test_mask_preserves_correct_region
    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/base.png', width: 500, height: 500 do
        mask 'test/assets/overlay.png'
      end
    end

    refute_nil image
    assert_equal 500, image.width
    assert_equal 500, image.height

    pixel = image.getpoint(250, 250)
    assert pixel[0].positive? || pixel[1].positive? || pixel[2].positive?, 'Center should have some color'
  end

  def test_mask_without_mask_unchanged
    reference_path = 'test/assets/base.png'

    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/base.png', width: 500, height: 500
    end

    expected = Vips::Image.new_from_file(reference_path)
    diff = (expected.cast(:float) - image.cast(:float)).abs.avg
    assert diff < 1.0, 'Image without mask should be nearly identical to source'
  end

  def test_displace_from_mask_generates_displacement_map
    reference = 'test/assets/references/mask_displace.png'

    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/grid.png', width: 200, height: 200 do
        displace from_mask: 'test/assets/disp_map.png', scale: 10, intensity: 0.5
      end
    end

    assert_image_similar(reference, image)
  end

  def test_relight_from_mask_generates_lighting
    reference = 'test/assets/references/mask_relight.png'

    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/base.png', width: 200, height: 200 do
        relight from_mask: 'test/assets/disp_map.png', strength: 1.2
      end
    end

    assert_image_similar(reference, image)
  end

  def test_combined_mask_displace_relight
    reference = 'test/assets/references/mask_combined.png'

    image = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/blue_square.png', width: 200, height: 200 do
        displace from_mask: 'test/assets/disp_map.png', scale: 8, intensity: 0.6
        relight from_mask: 'test/assets/disp_map.png', strength: 0.8
      end
    end

    assert_image_similar(reference, image)
  end

  def test_mask_in_group_context
    reference = 'test/assets/references/mask_in_group.png'

    image = Loomy.generate(size: [300, 300]) do
      group x: 50, y: 50, width: 200, height: 200 do
        layer 'test/assets/blue_square.png', fit: :cover, width: 200, height: 200 do
          mask 'test/assets/overlay.png'
        end
      end
    end

    assert_image_similar(reference, image)
  end

  def test_mask_with_alpha_channel
    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/overlay.png', width: 500, height: 500 do
        mask 'test/assets/overlay.png'
      end
    end

    refute_nil image
    assert_equal 500, image.width
    assert_equal 500, image.height
  end

  def test_displace_from_mask_with_different_intensity
    image1 = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/grid.png' do
        displace from_mask: 'test/assets/disp_map.png', scale: 10, intensity: 0.1
      end
    end

    image2 = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/grid.png' do
        displace from_mask: 'test/assets/disp_map.png', scale: 10, intensity: 1.5
      end
    end

    diff = (image1.cast(:float) - image2.cast(:float)).abs.avg
    assert diff > 10.0, "Different intensities should produce noticeably different results (diff: #{diff.round(2)})"
  end

  def test_relight_from_mask_with_different_strength
    image1 = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/base.png' do
        relight from_mask: 'test/assets/disp_map.png', strength: 0.2
      end
    end

    image2 = Loomy.generate(size: [200, 200]) do
      layer 'test/assets/base.png' do
        relight from_mask: 'test/assets/disp_map.png', strength: 2.5
      end
    end

    diff = (image1.cast(:float) - image2.cast(:float)).abs.avg
    assert diff > 10.0, "Different strengths should produce noticeably different results (diff: #{diff.round(2)})"
  end

  def test_multiple_layers_with_different_masks
    image = Loomy.generate(size: [500, 500]) do
      layer 'test/assets/blue_square.png', x: 50, y: 50, width: 200, height: 200 do
        mask 'test/assets/overlay.png'
      end
      layer 'test/assets/base.png', x: 250, y: 250, width: 200, height: 200 do
        mask 'test/assets/overlay.png'
      end
    end

    refute_nil image
    assert_equal 500, image.width
    assert_equal 500, image.height
  end
end
