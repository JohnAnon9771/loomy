# frozen_string_literal: true

require 'test_helper'

class SourceLoaderTest < Minitest::Test
  BASE = 'test/assets/base.png' # 500x500
  TRIMMABLE = 'test/assets/trim_test_source.png' # 500x500, 100x100 of content

  def setup
    @loader = Loomy::Render::SourceLoader.new
  end

  def test_reads_dimensions_without_decoding
    assert_equal [500, 500], @loader.dimensions(BASE)
  end

  def test_caches_by_path_and_target_size
    raw = @loader.load(BASE)
    raw_again = @loader.load(BASE)
    resized = @loader.load(BASE, width: 100, height: 100)

    assert_same raw, raw_again
    refute_same raw, resized
    assert_same resized, @loader.load(BASE, width: 100, height: 100)
  end

  def test_loads_at_the_requested_size
    image = @loader.load(BASE, width: 120, height: 120)

    assert_equal [120, 120], [image.width, image.height]
  end

  def test_missing_source_raises_a_loomy_error
    error = assert_raises(Loomy::SourceNotFound) { @loader.dimensions('test/assets/nope.png') }

    assert_match(/nope\.png/, error.message)
  end

  def test_trim_bounds_are_the_opaque_extent
    assert_equal [200, 200, 100, 100], @loader.trim_bounds(TRIMMABLE)
  end

  def test_trimmed_load_crops_then_scales_to_the_target
    # The old path loaded at twice the target width -- but only when that width
    # happened to be below 1000 -- then trimmed the downscaled copy. Cropping at
    # full resolution and scaling after is exact and needs no magic numbers.
    image = @loader.load_trimmed(TRIMMABLE, width: 50, height: 50)

    assert_equal [50, 50], [image.width, image.height]
    assert_equal [255, 0, 0, 255], image.getpoint(25, 25).map(&:to_i)
  end

  def test_trimmed_load_without_a_target_keeps_the_content_size
    image = @loader.load_trimmed(TRIMMABLE)

    assert_equal [100, 100], [image.width, image.height]
  end

  # PNG has no shrink-on-load, so routing it through Vips::Image.thumbnail(path)
  # decodes in full and then costs about twice as much as decoding and resizing
  # by hand. The two paths are pixel-identical, so this is purely about which
  # one gets used.
  def test_png_does_not_take_the_shrink_on_load_path
    refute_includes Loomy::Render::SourceLoader::SHRINK_ON_LOAD, 'pngload'
    assert_includes Loomy::Render::SourceLoader::SHRINK_ON_LOAD, 'jpegload'
  end

  def test_both_load_strategies_agree
    ours = @loader.load(BASE, width: 137, height: 137)
    shrink_on_load = Vips::Image.thumbnail(BASE, 137, height: 137, size: :both)

    assert_equal [shrink_on_load.width, shrink_on_load.height], [ours.width, ours.height]
    assert_in_delta 0.0, (ours.cast(:float) - shrink_on_load.cast(:float)).abs.avg, 0.001
  end
end
