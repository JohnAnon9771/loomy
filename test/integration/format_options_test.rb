# frozen_string_literal: true

require 'test_helper'

class FormatOptionsTest < Minitest::Test
  def setup
    FileUtils.mkdir_p('test/tmp')
    @high_q_path = 'test/tmp/high_q.jpg'
    @low_q_path = 'test/tmp/low_q.jpg'
  end

  def test_render_with_quality_options
    pipeline = proc do
      layer 'test/assets/base.png'
      layer 'test/assets/blue_square.png', x: 50, y: 50
    end

    # Render high quality
    Loomy.render(@high_q_path, quality: 100, size: [500, 500], &pipeline)

    # Render low quality
    Loomy.render(@low_q_path, quality: 10, size: [500, 500], &pipeline)

    assert File.exist?(@high_q_path)
    assert File.exist?(@low_q_path)

    # Low quality should be significantly smaller
    assert File.size(@low_q_path) < File.size(@high_q_path)
  end

  def test_render_webp_lossless
    webp_path = 'test/tmp/test.webp'
    # WebP uses lossless: true but also supports quality
    # For now testing just the existence and basic rendering
    Loomy.render(webp_path, size: [200, 200]) do
      layer 'test/assets/blue_square.png'
    end

    assert File.exist?(webp_path)
    img = Vips::Image.new_from_file(webp_path)
    assert_equal 200, img.width
    assert_equal 200, img.height
  end

  def test_to_blob_output
    blob = Loomy.to_blob('.png', compression: 9, size: [100, 100]) do
      layer 'test/assets/blue_square.png' do
        fit :contain
      end
    end

    assert blob.is_a?(String)
    assert blob.size.positive?

    # Load it back to verify
    img = Vips::Image.new_from_buffer(blob, '')
    assert_equal 100, img.width
    assert_equal 100, img.height
  end
end
