# frozen_string_literal: true

require 'test_helper'

class DpiTest < Minitest::Test
  def test_dpi_survives_to_blob
    # In-memory output has to carry dpi just like writing to a file does.
    blob = Loomy.to_blob('.png', size: [200, 200], dpi: 300) do
      layer 'test/assets/blue_square.png'
    end

    image = Vips::Image.new_from_buffer(blob, '')

    assert_in_delta 300.0 / 25.4, image.xres, 0.001
    assert_in_delta 300.0 / 25.4, image.yres, 0.001
  end

  def test_render_with_dpi_72
    output_path = tmp_path('dpi_72.png')
    Loomy.render(output_path, size: [200, 200], dpi: 72) do
      layer 'test/assets/blue_square.png'
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    expected_dpi = 72.0 / 25.4
    assert_in_delta expected_dpi, img.xres, 0.001
    assert_in_delta expected_dpi, img.yres, 0.001
  end

  def test_render_with_dpi_150
    output_path = tmp_path('dpi_150.png')
    Loomy.render(output_path, size: [200, 200], dpi: 150) do
      layer 'test/assets/blue_square.png'
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    expected_dpi = 150.0 / 25.4
    assert_in_delta expected_dpi, img.xres, 0.001
    assert_in_delta expected_dpi, img.yres, 0.001
  end

  def test_render_with_dpi_300
    output_path = tmp_path('dpi_300.png')
    Loomy.render(output_path, size: [200, 200], dpi: 300) do
      layer 'test/assets/blue_square.png'
    end

    assert File.exist?(output_path)
    img = Vips::Image.new_from_file(output_path)
    expected_dpi = 300.0 / 25.4
    assert_in_delta expected_dpi, img.xres, 0.001
    assert_in_delta expected_dpi, img.yres, 0.001
  end
end
