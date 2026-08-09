# frozen_string_literal: true

require 'test_helper'

# The taxonomy is a contract with whoever routes these errors, so its shape is
# asserted structurally rather than one class at a time. A leaf added without a
# category, or without a code, fails here instead of downstream.
class ErrorsTest < Minitest::Test
  CATEGORIES = [Loomy::DeclarationError, Loomy::ProcessingError].freeze

  def test_the_only_things_directly_under_error_are_the_two_categories
    assert_equal CATEGORIES.map(&:name).sort, Loomy::Error.subclasses.map(&:name).sort
  end

  # Which side of the fault line an error falls on is what a caller branches on,
  # so a leaf that belongs to neither category has nothing useful to say.
  def test_every_concrete_error_is_in_a_category
    leaves.each do |klass|
      assert_includes CATEGORIES, klass.superclass, "#{klass} is not in a category"
    end
  end

  # The code is the part that goes on a wire, so it is the part we keep stable --
  # not the class name. :unknown is the base class' answer and means somebody
  # added a leaf and forgot.
  def test_every_concrete_error_declares_a_unique_code
    codes = leaves.map { |klass| klass.allocate.code }

    refute_includes codes, :unknown
    assert_equal codes.sort, codes.uniq.sort
  end

  def test_everything_is_still_catchable_as_one
    assert_operator Loomy::InvalidSource, :<, Loomy::Error
    assert_operator Loomy::EncodeError, :<, Loomy::Error
  end

  # libvips' own message is worth showing and never worth matching, so it is
  # quoted under ours rather than folded into it.
  def test_libvips_detail_is_quoted_beneath_our_own_sentence
    error = Loomy::EncodeError.new('.zzz', 'VipsForeignSave: No known saver')

    assert_match(/Cannot encode to "\.zzz"/, error.message)
    assert_match(/libvips said: VipsForeignSave/, error.message)
  end

  # A badly truncated PNG leaves libvips' error buffer empty, and Vips::Error
  # then reports its own class name -- which would read as noise mid-sentence.
  def test_a_detail_that_says_nothing_is_dropped
    assert_equal Loomy::EncodeError.new('.zzz').message,
                 Loomy::EncodeError.new('.zzz', 'Vips::Error').message
  end

  private

  def leaves = CATEGORIES.flat_map(&:subclasses)
end
