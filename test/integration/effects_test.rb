# frozen_string_literal: true

require 'test_helper'

# pattern.png is a checkerboard with colour ramps rather than a flat field:
# blurring or soft-light compositing a uniform colour changes nothing, so a flat
# source cannot tell a working effect from a missing one.
class EffectsTest < Minitest::Test
  PATTERN = 'test/assets/pattern.png'
  MAP = 'test/assets/pattern_map.png'

  def test_blur
    assert_effect 'test/assets/references/blur.png' do
      blur radius: 5
    end
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

  def difference(one, other)
    (one.cast(:float) - other.cast(:float)).abs.avg
  end
end
