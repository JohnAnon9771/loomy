# frozen_string_literal: true

require 'test_helper'

class SourceCacheTest < Minitest::Test
  BASE = 'test/assets/base.png' # 500x500
  TRIMMABLE = 'test/assets/trim_test_source.png' # 500x500, 100x100 of content
  WHITE_ON_TRANSPARENT = 'test/assets/trim_white_on_transparent.png' # the same, in white
  ROTATED = 'test/assets/exif_rotated.jpg' # 200x100 of pixels, upright 100x200

  def setup
    @sources = Loomy::Render::SourceCache.new
  end

  def test_reads_dimensions_without_decoding
    assert_equal [500, 500], @sources.dimensions(BASE)
  end

  def test_dimensions_are_the_upright_ones
    assert_equal [100, 200], @sources.dimensions(ROTATED)
  end

  def test_missing_source_raises_a_loomy_error
    error = assert_raises(Loomy::SourceNotFound) { @sources.dimensions('test/assets/nope.png') }

    assert_match(/nope\.png/, error.message)
  end

  def test_trim_bounds_are_the_content_extent
    assert_equal [200, 200, 100, 100], @sources.trim_bounds(TRIMMABLE)
  end

  # Trimming is a full pixel scan. bounds_of and a `trim: true` layer on the
  # same source must not pay for it twice.
  def test_trim_bounds_are_scanned_once_per_path
    first = @sources.trim_bounds(TRIMMABLE)

    assert_same first, @sources.trim_bounds(TRIMMABLE)
  end

  # Two modes are two scans with two answers, so caching by path alone would
  # serve the second caller whatever the first happened to ask for.
  def test_each_mode_is_cached_and_scanned_separately
    alpha = @sources.trim_bounds(WHITE_ON_TRANSPARENT, :alpha)
    colour = @sources.trim_bounds(WHITE_ON_TRANSPARENT, :color)

    assert_equal [200, 200, 100, 100], alpha
    assert_equal [0, 0, 500, 500], colour
    assert_same alpha, @sources.trim_bounds(WHITE_ON_TRANSPARENT, :alpha)
  end

  def test_reports_the_libvips_loader_behind_a_path
    assert_equal 'pngload', @sources.loader_name(BASE)
    assert_equal 'jpegload', @sources.loader_name(ROTATED)
  end

  # A handle cannot change access mode once it is open, so a permission that
  # arrives late has to be ignored rather than half-applied.
  def test_streaming_cannot_be_granted_to_an_already_open_source
    @sources.dimensions(BASE)
    @sources.allow_streaming([BASE].to_set)

    # Random access is what makes a second read legal; under :sequential this
    # raises Vips::Error.
    @sources.oriented(BASE).avg
    @sources.oriented(BASE).avg
  end
end
