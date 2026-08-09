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

  def test_trim_rejects_a_non_boolean
    assert_raises(Loomy::InvalidValue) { build { layer 'test/assets/base.png', trim: :yes } }
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

  # libvips validates its own enum and its message lists every valid mode, so
  # duplicating that list here would only drift from the installed version.
  def test_blend_is_left_to_libvips
    error = assert_raises(Vips::Error) do
      Loomy.generate(size: [20, 20]) do
        layer solid: '#f00'
        layer solid: '#0f0', blend: :bogus
      end.write_to_memory
    end

    assert_match(/VipsBlendMode/, error.message)
  end

  private

  def build(&)
    Loomy::DSL::PipelineBuilder.new({ size: [100, 100] }, &).build
  end
end
