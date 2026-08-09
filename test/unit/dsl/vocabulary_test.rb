# frozen_string_literal: true

require 'test_helper'

# The DSL rejects an unknown property *name*; these cover an unknown *value*
# for a name it knows. Both forms of the DSL are checked, because keyword
# arguments and block calls reach the property hash by different routes.
class VocabularyTest < Minitest::Test
  def test_align_rejects_a_vertical_word
    error = assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', align: :top } }

    assert_equal :align, error.property
    assert_equal :top, error.value
    assert_match(/Expected: :left, :center, :right/, error.message)
  end

  def test_valign_rejects_a_horizontal_word
    assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', valign: :left } }
  end

  def test_the_block_form_is_checked_too
    assert_raises(Loomy::InvalidValue) do
      build do
        layer do
          solid '#f00'
          align :bottom
        end
      end
    end
  end

  def test_fit_rejects_an_unknown_mode
    assert_raises(Loomy::InvalidValue) { build { layer 'test/assets/base.png', fit: :squish } }
  end

  def test_trim_rejects_a_value_outside_its_vocabulary
    assert_raises(Loomy::InvalidValue) { build { layer 'test/assets/base.png', trim: :yes } }
  end

  def test_trim_accepts_a_named_mode
    canvas = build { layer 'test/assets/base.png', trim: :alpha }

    assert_equal :alpha, canvas.children.first.trim
    build { layer 'test/assets/base.png', trim: :color }
  end

  # :auto is what `trim: true` means, so writing it out has to be accepted the
  # same way `fit: :contain` is.
  def test_trim_accepts_its_default_spelled_out
    canvas = build { layer 'test/assets/base.png', trim: :auto }

    assert_equal :auto, canvas.children.first.trim
  end

  def test_distribute_rejects_an_unknown_mode
    assert_raises(Loomy::InvalidValue) { build { vstack(distribute: :around) { layer solid: '#f00' } } }
  end

  def test_stack_direction_is_checked
    assert_raises(Loomy::InvalidValue) { build { stack(:sideways) { layer solid: '#f00' } } }
  end

  def test_gradient_direction_is_checked_inside_the_hash
    error = assert_raises(Loomy::InvalidValue) do
      build { layer gradient: { from: '#000', to: '#fff', direction: :diagonal } }
    end

    assert_match(/top_bottom/, error.message)
  end

  def test_width_rejects_a_misspelled_fill
    # :fil is not a size, so layout read it as *undeclared* and the layer took
    # the whole parent box -- the same thing a correct :fill would have done,
    # which is what made the typo invisible.
    error = assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', width: :fil } }

    assert_equal :width, error.property
    assert_equal :fil, error.value
    assert_match(/Expected: an Integer of pixels, a percentage String such as "50%", or :fill/, error.message)
  end

  def test_height_rejects_a_string_that_forgot_its_percent_sign
    # '50' resolved to nothing: the layer silently took the parent's height
    # rather than half of it.
    error = assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', height: '50' } }

    assert_equal :height, error.property
  end

  def test_the_block_form_is_checked_for_dimensions_too
    assert_raises(Loomy::InvalidValue) do
      build do
        layer do
          solid '#f00'
          width :fil
        end
      end
    end
  end

  def test_dimensions_are_checked_on_containers
    assert_raises(Loomy::InvalidValue) { build { group(width: :fil) { layer solid: '#f00' } } }
    assert_raises(Loomy::InvalidValue) { build { vstack(height: '50') { layer solid: '#f00' } } }
  end

  def test_dimensions_accept_every_documented_form
    [10, '50%', '-10%', '12.5%', :fill].each do |dimension|
      build { layer solid: '#f00', width: dimension, height: dimension }
    end
  end

  # The mistake a clamp would have hidden, so this is the test that pins the
  # decision to raise.
  def test_opacity_rejects_a_percentage_written_as_a_whole_number
    error = assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', opacity: 50 } }

    assert_equal :opacity, error.property
    assert_equal 50, error.value
    assert_match(/Expected: a Numeric from 0\.0 \(invisible\) to 1\.0 \(unchanged\)/, error.message)
  end

  def test_opacity_rejects_a_negative_share
    assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', opacity: -0.5 } }
  end

  def test_the_block_form_is_checked_for_opacity_too
    assert_raises(Loomy::InvalidValue) do
      build do
        layer do
          solid '#f00'
          opacity 50
        end
      end
    end
  end

  def test_opacity_is_checked_on_containers
    assert_raises(Loomy::InvalidValue) { build { group(opacity: 2) { layer solid: '#f00' } } }
    assert_raises(Loomy::InvalidValue) { build { vstack(opacity: -1) { layer solid: '#f00' } } }
  end

  # NAN is why the rule is `(0..1).cover?` rather than `between?`: NAN.between?
  # raises ArgumentError, so the caller's mistake would arrive as something other
  # than a DeclarationError.
  def test_opacity_rejects_a_value_that_is_not_a_number
    [:half, '50%', Float::NAN].each do |value|
      assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', opacity: value } }
    end
  end

  def test_opacity_accepts_every_documented_form
    [0, 0.0, 0.5, 1, 1.0].each do |opacity|
      build { layer solid: '#f00', opacity: opacity }
    end
  end

  def test_premultiplied_is_checked_on_the_canvas
    error = assert_raises(Loomy::InvalidValue) { build(premultiplied: 'yes') { layer solid: '#f00' } }

    assert_equal :premultiplied, error.property
    assert_match(/Expected: true, false/, error.message)
  end

  # The canvas properties are built by slicing the options, and validation runs
  # before nils are dropped -- so an option nobody mentioned must not arrive as
  # a nil to be checked against a vocabulary that has no nil in it.
  def test_a_canvas_that_omits_premultiplied_still_builds
    build { layer solid: '#f00' }
  end

  def test_anchor_rejects_a_misspelled_half
    # The half that parses would still have applied; the other would silently
    # fall back to the top-left.
    assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', anchor: :botom_right } }
  end

  def test_anchor_rejects_two_words_from_the_same_axis
    assert_raises(Loomy::InvalidValue) { build { layer solid: '#f00', anchor: :left_right } }
  end

  def test_anchor_accepts_every_documented_form
    %i[top_left top_center top_right middle_left middle_center middle_right
       bottom_left bottom_center bottom_right center middle left top].each do |anchor|
      build { layer solid: '#f00', anchor: anchor }
    end
  end

  def test_valid_values_still_build
    canvas = build do
      hstack spacing: 4, valign: :middle, distribute: :space_between do
        layer solid: '#f00', width: 10, height: 10, align: :right
        layer 'test/assets/base.png', width: 10, fit: :cover, trim: true
      end
    end

    assert_equal 1, canvas.children.size
  end

  # libvips owns this vocabulary, so it is asked rather than copied: no list here
  # to drift from the installed version, and its answer still names every mode.
  #
  # It has to be a DeclarationError. The render wraps whatever libvips raises, so
  # leaving the mode unchecked reported the caller's typo as "libvips failed" --
  # the exact 4xx-read-as-5xx this taxonomy exists to prevent.
  def test_blend_is_asked_of_libvips
    error = assert_raises(Loomy::InvalidValue) do
      build { layer solid: '#0f0', blend: :bogus }
    end

    assert_equal :blend, error.property
    assert_equal :bogus, error.value
    assert_match(/soft-light/, error.message)
  end

  # Failing at declaration time, before any pixel work, is the point: the old
  # behaviour surfaced only once the image was written.
  def test_a_valid_blend_is_accepted
    canvas = build { layer solid: '#0f0', blend: :multiply }

    assert_equal 1, canvas.children.size
  end

  # The opposite case to blend: Loomy owns this vocabulary and maps it onto a
  # blend mode, so libvips never sees the name and cannot name the valid ones.
  # Unchecked, an unknown type reached the processor as a bare KeyError.
  def test_relight_type_is_checked_here
    error = assert_raises(Loomy::InvalidValue) do
      build { layer('test/assets/base.png') { relight map: 'test/assets/grid.png', type: :glow } }
    end

    assert_equal :type, error.property
    assert_match(/Expected: :soft, :hard/, error.message)
  end

  private

  def build(**, &)
    Loomy::DSL::PipelineBuilder.new(Loomy::Render::SourceCache.new, { size: [100, 100], ** }, &).build
  end
end
