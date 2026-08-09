# frozen_string_literal: true

require 'test_helper'

# The matrix from issue #9: every subject/background pair where "where is the
# content?" has an obvious right answer, checked against both modes.
#
# Images are built in memory rather than committed to test/assets, because what
# is under test is arithmetic over pixels, not a rendered composition. Nothing
# here derives a golden, so a fixture would only be a binary standing in for two
# lines of Vips.
#
# The `.cast(:uchar).copy(interpretation: :srgb)` on every one of them is load
# bearing, and the reason `srgb` is spelled out rather than left to default:
# `Vips::Image.black(w, h, bands: 3).bandjoin(255)` comes back as :multiband,
# where `has_alpha?` is false and find_trim compares four colour bands against
# white instead of flattening the fourth against it. The results change, and a
# test written on those images measures something no real PNG does.
class TrimmerTest < Minitest::Test
  SIZE = 500
  CONTENT = 100
  ORIGIN = 200

  # 100x100 opaque subject at 200,200 inside 500x500 of transparency.
  EXPECTED = [ORIGIN, ORIGIN, CONTENT, CONTENT].freeze
  WHOLE = [0, 0, SIZE, SIZE].freeze

  # The case the issue was opened for. find_trim's background defaults to white,
  # so a white subject *is* the background: the whole image reads as border and
  # the scan comes back empty. Before the alpha mode existed the empty result
  # fell back to the full image, and the layer rendered untrimmed with nothing
  # to say it had.
  def test_a_white_subject_on_transparency_is_found_by_alpha_and_missed_by_colour
    image = on_transparent([255, 255, 255])

    assert_equal EXPECTED, bounds(image, :alpha)
    assert_equal WHOLE, bounds(image, :color)
    assert_equal EXPECTED, bounds(image, :auto), 'auto has to pick the mode that can answer'
  end

  # `trim: true` reaches here as itself rather than as the mode it stands for,
  # so the two spellings have to mean the same thing all the way down.
  def test_true_is_the_same_request_as_auto
    image = on_transparent([255, 255, 255])

    assert_equal bounds(image, :auto), bounds(image, true)
  end

  # Near-white fails the same way: what decides is distance from white against
  # the threshold, not whether the subject is white on the nose.
  def test_a_near_white_subject_on_transparency_is_missed_by_colour
    image = on_transparent([250, 250, 250])

    assert_equal EXPECTED, bounds(image, :alpha)
    assert_equal WHOLE, bounds(image, :color)
  end

  # Black is far enough from white that the colour scan happens to work, which
  # is exactly why the bug went unnoticed: the modes agree on most artwork.
  def test_a_black_subject_on_transparency_is_found_by_both
    image = on_transparent([0, 0, 0])

    assert_equal EXPECTED, bounds(image, :alpha)
    assert_equal EXPECTED, bounds(image, :color)
  end

  # Nothing about the answer may depend on how many bands the colour is spread
  # across, which was the original wording of the issue.
  def test_greyscale_and_cmyk_subjects_are_found_by_alpha
    grey = grey_on_transparent
    cmyk = on_transparent([255, 255, 255]).colourspace(:cmyk)

    assert_equal EXPECTED, bounds(grey, :alpha)
    assert_equal EXPECTED, bounds(cmyk, :alpha)
  end

  # A 4-band CMYK image has no alpha to read, so :color is what `true` resolves
  # to -- and :color is the mode that cannot see a white subject.
  def test_a_cmyk_subject_has_no_alpha_to_trim_by
    image = on_transparent([255, 255, 255]).flatten(background: [0, 0, 0]).colourspace(:cmyk)

    refute_predicate image, :has_alpha?
    assert_equal WHOLE, bounds(image, :alpha)
  end

  # find_trim median-filters before scanning, so a single pixel of content is
  # smoothed away and the image reports empty. The alpha scan is exact.
  def test_a_single_pixel_of_content_survives_the_alpha_scan
    image = srgb(
      Vips::Image.black(1, 1, bands: 3).linear([1], [255, 255, 255]).bandjoin(255)
                 .embed(250, 250, SIZE, SIZE, extend: :background, background: [0, 0, 0, 0])
    )

    assert_equal [250, 250, 1, 1], bounds(image, :alpha)
    assert_equal WHOLE, bounds(image, :color)
  end

  # Exact means exact: an antialiased edge is content down to the faintest
  # pixel, so the box is a little larger than the shape's nominal size.
  def test_an_antialiased_edge_is_kept_whole
    image = srgb(on_transparent([255, 0, 0]).gaussblur(4))
    left, top, width, height = bounds(image, :alpha)

    assert_operator width, :>, CONTENT
    assert_operator left, :<, ORIGIN
    assert_equal [left, width], [top, height], 'a symmetric subject blurs symmetrically'
  end

  # A source with nothing to find reports its own extent rather than an empty
  # box, so measure and render agree without either of them holding a guard.
  def test_an_image_with_nothing_to_find_reports_its_full_extent
    transparent = srgb(Vips::Image.black(SIZE, SIZE, bands: 3).bandjoin(0))
    uniform = srgb(Vips::Image.black(SIZE, SIZE, bands: 3).linear([1], [255, 255, 255]))

    assert_equal WHOLE, bounds(transparent, :alpha)
    assert_equal WHOLE, bounds(transparent, :color)
    assert_equal WHOLE, bounds(uniform, :color)
  end

  # The colour mode is not a legacy path kept for compatibility: it is the only
  # one that can trim opaque artwork, where there is no alpha to read.
  def test_an_opaque_border_is_only_trimmable_by_colour
    image = srgb(
      Vips::Image.black(CONTENT, CONTENT, bands: 3).linear([1], [255, 0, 0])
                 .embed(ORIGIN, ORIGIN, SIZE, SIZE, extend: :white)
    )

    refute_predicate image, :has_alpha?
    assert_equal EXPECTED, bounds(image, :color)
    assert_equal EXPECTED, bounds(image), 'true falls back to colour without an alpha channel'
    assert_equal WHOLE, bounds(image, :alpha)
  end

  # Content running to the edge is not a degenerate case and must not trigger
  # the fallback: the answer and the fallback simply coincide.
  def test_content_filling_the_frame_measures_as_the_frame
    assert_equal WHOLE, bounds(srgb(Vips::Image.black(SIZE, SIZE, bands: 3).bandjoin(255)), :alpha)
  end

  # These are crop arguments and frame dimensions downstream; libvips answers
  # `min` with a Float and layout does integer arithmetic on the result.
  def test_bounds_are_integers
    assert(bounds(on_transparent([255, 255, 255]), :alpha).all?(Integer))
  end

  private

  def bounds(image, mode = :auto) = Loomy::Render::Trimmer.bounds(image, mode)

  def srgb(image) = image.cast(:uchar).copy(interpretation: :srgb)

  def on_transparent(rgb)
    srgb(
      Vips::Image.black(CONTENT, CONTENT, bands: 3).linear([1], rgb).bandjoin(255)
                 .embed(ORIGIN, ORIGIN, SIZE, SIZE, extend: :background, background: [0, 0, 0, 0])
    )
  end

  def grey_on_transparent
    Vips::Image.black(CONTENT, CONTENT, bands: 1).linear([1], [255]).bandjoin(255)
               .embed(ORIGIN, ORIGIN, SIZE, SIZE, extend: :background, background: [0, 0])
               .cast(:uchar).copy(interpretation: :'b-w')
  end
end
