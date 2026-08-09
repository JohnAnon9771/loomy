# frozen_string_literal: true

require 'test_helper'

# What a consumer mapping errors to HTTP statuses actually sees, through the
# public API. The point of every test here is which *category* comes back: the
# whole taxonomy exists so that "the image you sent is broken" and "we could not
# carry it out" can be told apart without matching on a libvips message.
class ErrorsIntegrationTest < Minitest::Test
  BASE = 'test/assets/base.png'
  GRID = 'test/assets/grid.png'

  # libvips is demand-driven, so pixels are read for the first time during the
  # write -- the same call an unsupported format fails in. These two tests are the
  # pair that has to come apart.
  def test_a_truncated_source_is_the_callers_fault
    path = truncated_copy

    error = assert_raises(Loomy::InvalidSource) do
      Loomy.to_blob('.png', size: [40, 40]) { layer path }
    end

    assert_equal path, error.path
    assert_kind_of Vips::Error, error.cause
  end

  # The regression this file exists for. The failed render has already consumed
  # its streamed sources, so asking those same handles whether they decode says
  # "broken" about two perfectly good files -- and a 500 gets reported as a 422.
  def test_a_bad_write_option_is_not_blamed_on_healthy_sources
    error = assert_raises(Loomy::ProcessingError) do
      Loomy.to_blob('.png', size: [40, 40], not_an_option: 1) do
        layer BASE
        layer GRID, x: 10, y: 10
      end
    end

    assert_kind_of Loomy::EncodeError, error
    assert_equal '.png', error.target
  end

  def test_an_unsupported_format_is_an_encode_error
    error = assert_raises(Loomy::EncodeError) do
      Loomy.to_blob('.zzz', size: [10, 10]) { layer solid: '#f00' }
    end

    assert_equal '.zzz', error.target
    assert_kind_of Vips::Error, error.cause
  end

  # ruby-vips converts write options to the types libvips declared them with, so
  # this fails as a TypeError before libvips is reached at all. Rescuing only
  # Vips::Error would let it escape the hierarchy.
  def test_a_write_option_of_the_wrong_type_is_an_encode_error
    error = assert_raises(Loomy::EncodeError) do
      Loomy.to_blob('.jpg', size: [10, 10], quality: 'high') { layer solid: '#f00' }
    end

    assert_kind_of TypeError, error.cause
  end

  # It fails at declaration time now, so it never reaches the render whose
  # Vips::Error would have been reported as our fault rather than the caller's.
  def test_an_unknown_blend_mode_is_the_callers_fault
    assert_raises(Loomy::DeclarationError) do
      Loomy.to_blob('.png', size: [20, 20]) { layer solid: '#f00', blend: :bogus }
    end
  end

  # A truncated PNG used to open, measure, composite and write with no exception
  # at all: libvips filled the missing half and the output was quietly wrong. The
  # same file has always been refused when it is a JPEG, so the old behaviour also
  # depended on the format.
  #
  # `render` rather than `to_blob` because it writes through a different libvips
  # saver, and reports the destination rather than a format.
  #
  # What is deliberately *not* asserted is that the destination is untouched.
  # Whether a saver that fails part-way leaves a partial file behind is its own
  # business and it moves between libvips versions -- 8.18 leaves nothing, older
  # builds leave a stub. Loomy raising rather than reporting success is the part
  # that is ours to promise.
  def test_a_truncated_source_never_renders_half_an_image
    path = truncated_copy(name: 'half.png')

    error = assert_raises(Loomy::InvalidSource) do
      Loomy.render(tmp_path('half_output.png'), size: [40, 40]) { layer path }
    end

    assert_equal path, error.path
  end

  # The shrink-on-load formats decode straight to a reduced size, which reopens
  # the file by name and so bypasses the cache's own handle. That second open has
  # to repeat the cache's strictness, or the formats most likely to arrive from a
  # browser would be the only ones a truncated file got through.
  def test_a_truncated_jpeg_is_refused_on_the_shrink_on_load_path
    path = truncated_copy('test/assets/exif_rotated.jpg')

    assert_equal 'jpegload', Loomy::Render::SourceCache.new.loader_name(path)

    error = assert_raises(Loomy::InvalidSource) do
      Loomy.to_blob('.png', size: [40, 40]) { layer path }
    end

    assert_equal path, error.path
  end

  # `render` writes to a path, so a destination libvips cannot open is a third way
  # the same call fails -- and it is ours to report, not the source's.
  def test_an_unwritable_destination_is_an_encode_error
    error = assert_raises(Loomy::EncodeError) do
      Loomy.render('/nope/does/not/exist/out.png', size: [10, 10]) { layer solid: '#f00' }
    end

    assert_equal '/nope/does/not/exist/out.png', error.target
  end

  # Both sides of the line, as a consumer would write them.
  def test_the_two_categories_cover_every_case_here
    declaration = [
      -> { Loomy.to_blob('.png', size: [10, 10]) { layer 'test/assets/nope.png' } },
      -> { Loomy.to_blob('.png', size: [10, 10]) { layer 'Gemfile' } },
      -> { Loomy.to_blob('.png', size: [10, 10]) { layer solid: '#nothex' } }
    ]
    processing = [
      -> { Loomy.to_blob('.zzz', size: [10, 10]) { layer solid: '#f00' } }
    ]

    declaration.each { |attempt| assert_raises(Loomy::DeclarationError, &attempt) }
    processing.each { |attempt| assert_raises(Loomy::ProcessingError, &attempt) }
  end

  # Every wrapped error keeps the original reachable, so the libvips text stays
  # available to read even though nothing should branch on it.
  def test_a_wrapped_error_keeps_libvips_message_and_cause
    error = assert_raises(Loomy::EncodeError) do
      Loomy.to_blob('.zzz', size: [10, 10]) { layer solid: '#f00' }
    end

    assert_match(/libvips said:/, error.message)
    assert_equal error.cause.message.strip, error.message.split('libvips said: ').last
  end
end
