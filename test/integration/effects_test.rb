# frozen_string_literal: true

require 'test_helper'

# pattern.png is a checkerboard with colour ramps rather than a flat field:
# blurring or soft-light compositing a uniform colour changes nothing, so a flat
# source cannot tell a working effect from a missing one.
class EffectsTest < Minitest::Test
  PATTERN = 'test/assets/pattern.png'
  MAP = 'test/assets/pattern_map.png'
  GRID = 'test/assets/grid.png'
  TRANSLUCENT = '#3366cc80'

  def test_blur
    assert_effect 'test/assets/references/blur.png' do
      blur radius: 5
    end
  end

  def test_color_adjustment
    assert_effect 'test/assets/references/color_adjustment.png' do
      adjust_color brightness: 1.2, contrast: 1.3
    end
  end

  # Contrast used to be folded into the same gain as brightness, which made the
  # two indistinguishable. It expands around mid-grey, so mid-grey itself is the
  # one value it cannot move; brightness moves everything.
  def test_contrast_pivots_around_mid_grey_and_brightness_does_not
    expanded = mid_grey_after { adjust_color contrast: 2.0 }
    compressed = mid_grey_after { adjust_color contrast: 0.5 }
    brightened = mid_grey_after { adjust_color brightness: 2.0 }

    assert_equal [128, 128, 128], expanded
    assert_equal [128, 128, 128], compressed
    assert_equal [255, 255, 255], brightened
  end

  # sRGB -> greyscale coefficients vary between libvips releases, so the
  # reference is only exact on the version it was rendered with. The band
  # equality below is what actually pins the behaviour.
  def test_grayscale
    image = assert_effect('test/assets/references/grayscale.png', across_libvips: 3.0) { grayscale }

    # Grey means the three colour bands agree.
    pixel = image.getpoint(10, 10)

    assert_in_delta pixel[0], pixel[1], 1
    assert_in_delta pixel[1], pixel[2], 1
  end

  def test_displacement
    assert_effect 'test/assets/references/displacement.png' do
      displace map: MAP, scale: 20
    end
  end

  def test_lighting
    assert_effect 'test/assets/references/lighting.png' do
      relight map: MAP, type: :soft
    end
  end

  # The processor used to composite a fixed :soft_light, so `type` picked
  # nothing and the two spellings rendered the same image.
  def test_hard_light_is_not_soft_light
    soft = render { relight map: MAP, type: :soft }
    hard = render { relight map: MAP, type: :hard }

    refute_in_delta 0.0, difference(soft, hard), 1.0
  end

  # `strength` was read by nothing but the pruner: 0.1 and 9.0 rendered
  # identically. Scaling the map around mid-grey is what makes it mean
  # something, and mid-grey is exactly what both blends leave alone.
  def test_strength_scales_how_far_the_light_is_pushed
    distances = [0.25, 1.0, 2.0].map { |s| difference(source, render { relight map: MAP, strength: s }) }

    assert_equal distances.sort, distances
    refute_in_delta distances.first, distances.last, 1.0
  end

  # A negative strength inverts the map: highlight becomes shadow. It is a
  # picture, not an absence, so the pruner has to let it through.
  def test_negative_strength_inverts_the_light
    inverted = render { relight map: MAP, strength: -1.0 }

    refute_in_delta 0.0, difference(source, inverted), 1.0
    refute_in_delta 0.0, difference(render { relight map: MAP, strength: 1.0 }, inverted), 1.0
  end

  # Alpha is not a colour, but `linear` broadcasts across every band: brightening
  # a half-transparent layer used to double its opacity into full opacity.
  def test_adjust_color_leaves_alpha_alone
    image = translucent { adjust_color brightness: 2.0 }

    assert_in_delta 128, image.getpoint(5, 5).last, 0.5
  end

  # Compositing an opaque map over a translucent image takes the map's opacity
  # with it, and leaves the map's own colour behind where the image was not.
  def test_relight_leaves_alpha_alone
    image = translucent { relight map: MAP }

    assert_in_delta 128, image.getpoint(5, 5).last, 0.5
  end

  # The same bug seen from the outside: a group's empty margin came back painted
  # flat grey, because the map was composited over nothing.
  def test_relight_does_not_light_what_is_not_there
    image = Loomy.generate(size: [40, 40]) do
      group width: 40, height: 40 do
        layer solid: '#0f0', width: 20, height: 20
        relight map: MAP
      end
    end

    assert_equal [0, 0, 0, 0], image.getpoint(30, 30).map(&:to_i)
  end

  def test_effects_apply_in_declaration_order
    blur_then_grey = render do
      blur(radius: 4)
      grayscale
    end
    grey_then_blur = render do
      grayscale
      blur(radius: 4)
    end

    refute_in_delta 0.0, difference(blur_then_grey, grey_then_blur), 0.01
  end

  def test_an_effect_with_a_missing_map_names_the_file
    error = assert_raises(Loomy::SourceNotFound) do
      render { displace(map: 'test/assets/no_such_map.png') }.write_to_memory
    end

    assert_match(/no_such_map/, error.message)
  end

  private

  # Checks both that the effect changed something and that what it produced
  # still matches the reference.
  def assert_effect(reference, across_libvips: nil, &)
    image = render(&)

    refute_in_delta 0.0, difference(Vips::Image.new_from_file(PATTERN), image), 0.5,
                    'the effect left the image unchanged, so this test would pass with the effect removed'
    assert_image_similar(reference, image, across_libvips: across_libvips)

    image
  end

  def render(&effect)
    Loomy.generate(size: [200, 200]) do
      layer PATTERN, &effect
    end
  end

  # grid.png is a flat mid-grey field, which is the one value contrast cannot
  # move. Rendered at its own size so nothing resamples the pixel being read.
  def mid_grey_after(&effect)
    Loomy.generate(size: [200, 200]) { layer(GRID, &effect) }.getpoint(0, 0).first(3).map(&:to_i)
  end

  def source = Vips::Image.new_from_file(PATTERN)

  def translucent(&effect)
    Loomy.generate(size: [20, 20]) { layer(solid: TRANSLUCENT, width: 20, height: 20, &effect) }
  end

  def difference(one, other)
    (one.cast(:float) - other.cast(:float)).abs.avg
  end
end
