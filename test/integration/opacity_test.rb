# frozen_string_literal: true

require 'test_helper'

# `opacity` scales a node's alpha where it meets its parent, so it applies to
# layers, groups and stacks alike -- anything that can be somebody's child.
class OpacityTest < Minitest::Test
  PATTERN = 'test/assets/pattern.png'

  def test_opacity_halves_a_layer_over_its_background
    image = Loomy.generate(size: [10, 10]) do
      layer solid: '#ffffff'
      layer solid: '#ff0000', opacity: 0.5
    end

    assert_in_delta 127, image.getpoint(5, 5)[1], 1.0
  end

  # Not just the same pixels: the same band format. A fade that dropped the cast
  # would still halve the alpha correctly and only show up here.
  def test_opacity_1_is_the_image_untouched
    plain = Loomy.generate(size: [40, 40]) { layer PATTERN }
    unfaded = Loomy.generate(size: [40, 40]) { layer PATTERN, opacity: 1.0 }

    assert_equal 0.0, (plain.cast(:float) - unfaded.cast(:float)).abs.max
    assert_equal plain.format, unfaded.format
  end

  # Asserted on its own, away from any pixel value, so a float promotion is
  # unambiguous here rather than showing up as thirteen goldens drifting.
  def test_opacity_does_not_promote_the_band_format
    image = Loomy.generate(size: [40, 40]) { layer PATTERN, opacity: 0.5 }

    assert_equal :uchar, image.format
  end

  def test_opacity_0_is_invisible
    image = Loomy.generate(size: [10, 10]) { layer solid: '#ff0000', opacity: 0 }

    assert_equal [0, 0, 0, 0], image.getpoint(5, 5).map(&:to_i)
  end

  # Invisible, not absent. Pruning an `opacity: 0` node would look like a free
  # optimisation and would move everything after it: the blue band starts at
  # y=20 here and would start at y=10 without its faded sibling holding the slot.
  def test_opacity_0_still_holds_its_slot_in_a_stack
    image = Loomy.generate(size: [10, 30]) do
      vstack do
        layer solid: '#ff0000', width: 10, height: 10
        layer solid: '#00ff00', width: 10, height: 10, opacity: 0
        layer solid: '#0000ff', width: 10, height: 10
      end
    end

    assert_equal [255, 0, 0, 255], image.getpoint(5, 5).map(&:to_i)
    assert_equal [0, 0, 0, 0], image.getpoint(5, 15).map(&:to_i)
    assert_equal [0, 0, 255, 255], image.getpoint(5, 25).map(&:to_i)
  end

  # Fading a group is not fading its children. Where two children overlap, one
  # composed thing at half opacity is 127; two half-opacity things stacked is 64,
  # because the second fills in half of what the first left. Only the first is
  # what `group opacity: 0.5` should mean, and it is unreachable per child.
  def test_group_opacity_is_not_the_same_as_fading_each_child
    grouped = Loomy.generate(size: [30, 30]) do
      layer solid: '#ffffff'
      group opacity: 0.5 do
        layer solid: '#ff0000', width: 20, height: 20
        layer solid: '#ff0000', x: 5, y: 5, width: 20, height: 20
      end
    end

    per_child = Loomy.generate(size: [30, 30]) do
      layer solid: '#ffffff'
      layer solid: '#ff0000', width: 20, height: 20, opacity: 0.5
      layer solid: '#ff0000', x: 5, y: 5, width: 20, height: 20, opacity: 0.5
    end

    assert_in_delta 127, grouped.getpoint(10, 10)[1], 1.0
    assert_in_delta 64, per_child.getpoint(10, 10)[1], 1.0
  end

  def test_opacity_applies_to_a_stack
    image = Loomy.generate(size: [10, 10]) do
      layer solid: '#ffffff'
      vstack(opacity: 0.5) { layer solid: '#ff0000', width: 10, height: 10 }
    end

    assert_in_delta 127, image.getpoint(5, 5)[1], 1.0
  end

  # Effects run first, then opacity. Reversed, blur would smear the reduced alpha
  # into its neighbours. Both assertions are needed: the alpha alone is satisfied
  # by either order, and the difference alone is satisfied by a blur that ran
  # without any fade at all.
  def test_opacity_applies_after_the_node_effects
    blurred = Loomy.generate(size: [200, 200]) { layer(PATTERN, opacity: 0.5) { blur radius: 5 } }
    sharp = Loomy.generate(size: [200, 200]) { layer PATTERN, opacity: 0.5 }

    assert_in_delta 127, blurred.getpoint(100, 100).last, 1.0
    refute_in_delta 0.0, (blurred.cast(:float) - sharp.cast(:float)).abs.avg, 1.0
  end

  # Resized, so the loader hands the fade three bands and no alpha. Without its
  # own has_alpha? check the fade scales the blue band and the layer stays opaque
  # -- which is why the colour is asserted alongside the alpha.
  def test_opacity_fades_a_source_that_has_no_alpha_channel
    image = Loomy.generate(size: [20, 20]) do
      layer 'test/assets/exif_rotated.jpg', width: 20, height: 20, fit: :stretch, opacity: 0.5
    end

    assert_equal [200, 60, 59], image.getpoint(10, 10).first(3).map(&:to_i)
    assert_in_delta 127, image.getpoint(10, 10).last, 1.0
  end
end
