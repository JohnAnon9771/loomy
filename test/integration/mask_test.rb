# frozen_string_literal: true

require 'test_helper'

class MaskTest < Minitest::Test
  def setup
    FileUtils.mkdir_p('test/tmp')
  end

  def test_mask_with_dest_in
    output_path = 'test/tmp/mask_dest_in.png'
    Loomy.render(output_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png', mask: 'test/assets/mask_square.png', mask_method: :dest_in
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    assert_equal 200, img.width
    assert_equal 200, img.height
  end

  def test_mask_with_dest_out
    output_path = 'test/tmp/mask_dest_out.png'
    Loomy.render(output_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png', mask: 'test/assets/mask_square.png', mask_method: :dest_out
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    assert_equal 200, img.width
    assert_equal 200, img.height
  end

  def test_mask_with_source
    output_path = 'test/tmp/mask_source.png'
    Loomy.render(output_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png', mask: 'test/assets/mask_square.png', mask_method: :source
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    assert_equal 200, img.width
    assert_equal 200, img.height
  end

  def test_mask_with_over
    output_path = 'test/tmp/mask_over.png'
    Loomy.render(output_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png', mask: 'test/assets/mask_square.png', mask_method: :over
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    assert_equal 200, img.width
    assert_equal 200, img.height
  end

  def test_mask_compositing_changes_output
    base_path = 'test/tmp/mask_base.png'
    with_mask_path = 'test/tmp/mask_comparison.png'

    Loomy.render(base_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png'
    end

    Loomy.render(with_mask_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png', mask: 'test/assets/mask_square.png', mask_method: :dest_in
    end

    base_img = Vips::Image.new_from_file(base_path)
    masked_img = Vips::Image.new_from_file(with_mask_path)
    refute_equal base_img.avg, masked_img.avg
  end
end