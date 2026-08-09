# frozen_string_literal: true

require 'test_helper'

# `premultiplied` tells libvips that the images it is compositing already carry
# premultiplied alpha. Loomy's layers do not -- the flag exists so a render can
# reproduce a pipeline that makes the same claim, where `pm` is true whenever the
# base image is under a multiply filter.
#
# Solids rather than assets: the composite is then flat, so one pixel carries the
# whole result and the expected values are exact integers with no golden to drift
# against a libvips build.
class PremultipliedTest < Minitest::Test
  BASE    = '#b4783c80' # 180, 120, 60 at alpha 128 -- a base that has alpha
  OVERLAY = '#0000ffc8' #   0,   0, 255 at alpha 200

  SIZE = [64, 64].freeze

  PLAIN      = [21, 14, 129, 227].freeze
  PREMULTIED = [38, 25, 163, 227].freeze

  # The cross the option exists for: pm x multiply x a base with alpha. Anywhere
  # else the flag is either a no-op or a rounding difference; here it is 15.6 MAE
  # apart, so this cannot pass by accident.
  def test_premultiplied_changes_a_multiply_over_a_base_with_alpha
    assert_equal PLAIN, pixel(render)
    assert_equal PREMULTIED, pixel(render(premultiplied: true))
  end

  # Loomy composites onto a transparent canvas; the pipeline being reproduced
  # composites straight onto the base. The two are the same picture -- exactly,
  # not approximately, and under either reading of alpha. That identity is what
  # licenses replacing the other pipeline, and multiply over a translucent base
  # is the case where it would break first if it broke at all.
  def test_compositing_onto_a_transparent_canvas_equals_compositing_onto_the_base
    [false, true].each do |premultiplied|
      combined = render(premultiplied: premultiplied)
      onto_base = Loomy.generate(size: SIZE, premultiplied: premultiplied) { layer solid: BASE }
                       .composite2(Loomy.generate(size: SIZE) { layer solid: OVERLAY },
                                   :multiply, premultiplied: premultiplied)

      assert_in_delta 0.0, ((combined - onto_base)**2).avg, 1e-9,
                      "transparent-canvas and onto-base composites diverge at premultiplied: #{premultiplied}"
    end
  end

  # The flag describes how alpha is read for the whole render, so it has to reach
  # the composites inside groups too. Applied to the canvas alone it would be
  # inert for any tree that nests: the single `over` of a group onto the canvas
  # gives PLAIN either way, so turning the option on would silently do nothing.
  def test_nested_composites_see_the_flag
    nested = Loomy.generate(size: SIZE, premultiplied: true) do
      group do
        layer solid: BASE
        layer solid: OVERLAY, blend: :multiply
      end
    end

    assert_equal PREMULTIED, pixel(nested)
  end

  # Premultiplied and straight coincide wherever alpha is 255, so every golden in
  # the suite -- all rendered from opaque assets -- is out of this option's reach.
  def test_the_flag_is_a_no_op_on_opaque_sources
    opaque = proc do
      layer 'test/assets/base.png'
      layer 'test/assets/overlay.png', blend: :multiply
    end

    plain = Loomy.generate(size: [500, 500], &opaque)
    premultiplied = Loomy.generate(size: [500, 500], premultiplied: true, &opaque)

    assert_equal 0.0, (plain - premultiplied).abs.max
  end

  # A canvas option has to survive every entry point. dpi once reached render but
  # not to_blob, and the two share CANVAS_OPTIONS now so they cannot diverge
  # again -- this fails on either half of that: dropping the option, or letting it
  # through to the saver, which refuses it.
  def test_premultiplied_survives_to_blob_alongside_a_write_option
    blob = Loomy.to_blob('.png', size: SIZE, premultiplied: true, compression: 9) do
      layer solid: BASE
      layer solid: OVERLAY, blend: :multiply
    end

    assert_equal PREMULTIED, pixel(Vips::Image.new_from_buffer(blob, ''))
  end

  def test_premultiplied_survives_render
    output_path = tmp_path('premultiplied.png')
    Loomy.render(output_path, size: SIZE, premultiplied: true) do
      layer solid: BASE
      layer solid: OVERLAY, blend: :multiply
    end

    assert_equal PREMULTIED, pixel(Vips::Image.new_from_file(output_path))
  end

  private

  def render(**options)
    Loomy.generate(size: SIZE, **options) do
      layer solid: BASE
      layer solid: OVERLAY, blend: :multiply
    end
  end

  def pixel(image) = image.getpoint(32, 32).map(&:to_i)
end
