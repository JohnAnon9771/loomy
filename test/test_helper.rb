# frozen_string_literal: true

require 'loomy'
require 'minitest/autorun'
require 'vips'
require 'fileutils'

# Test fixtures under test/assets are committed binaries, not generated at run
# time. They are the inputs the golden references in test/assets/references were
# produced from, so regenerating them from code would silently move every
# golden. test/fixtures_test.rb pins their contract instead.
module TestHelper
  TMP_DIR = 'test/tmp'

  MISSING_REFERENCE = <<~MSG
    Reference image not found: %s

    If this is a new golden test, generate the baseline deliberately:

        bundle exec rake test:baseline

    Then inspect the generated PNG before committing it. References are the
    visual contract of the suite; they must never be created as a side effect
    of a normal test run.
  MSG

  # Golden images are only exactly reproducible against the libvips build they
  # were rendered with: resampling kernels and colourspace conversions change
  # between releases. References here were produced on this version, so tests
  # stay strict on it and may relax elsewhere -- see assert_image_similar.
  REFERENCE_LIBVIPS = '8.18'

  def self.libvips_version
    "#{Vips.version(0)}.#{Vips.version(1)}"
  end

  def self.reference_libvips?
    libvips_version == REFERENCE_LIBVIPS
  end

  def self.baseline_mode?
    ENV['LOOMY_BASELINE'] == '1'
  end

  def self.setup_tmp_dir
    FileUtils.mkdir_p(TMP_DIR)
  end

  # Path for a test to write output into. Never write to the repo root or into
  # test/assets: both are versioned.
  def tmp_path(name)
    FileUtils.mkdir_p(TestHelper::TMP_DIR)
    File.join(TestHelper::TMP_DIR, name)
  end

  # `across_libvips` is the tolerance to use when the running libvips is not the
  # one the references were rendered with. Pass it only for the handful of
  # operations that genuinely move between releases, and only where a
  # version-independent assertion in the test itself carries the real weight --
  # otherwise the golden stops meaning anything.
  def assert_image_similar(expected_path, actual_image, tolerance: 0.1, across_libvips: nil)
    tolerance = across_libvips if across_libvips && !TestHelper.reference_libvips?
    actual = actual_image.is_a?(String) ? Vips::Image.new_from_file(actual_image) : actual_image

    if TestHelper.baseline_mode?
      FileUtils.mkdir_p(File.dirname(expected_path))
      actual.write_to_file(expected_path)
      return
    end

    flunk(format(TestHelper::MISSING_REFERENCE, expected_path)) unless File.exist?(expected_path)

    expected = Vips::Image.new_from_file(expected_path)

    if expected.width != actual.width || expected.height != actual.height
      flunk "Image dimensions mismatch for #{expected_path}: " \
            "expected #{expected.width}x#{expected.height}, got #{actual.width}x#{actual.height}"
    end

    if expected.bands != actual.bands
      flunk "Image band count mismatch for #{expected_path}: " \
            "expected #{expected.bands}, got #{actual.bands}"
    end

    # Mean Absolute Error. Cast to float first so per-band subtraction cannot
    # wrap around on uchar data.
    diff = (expected.cast(:float) - actual.cast(:float)).abs.avg

    assert diff <= tolerance,
           "Image similarity failed for #{expected_path}. Mean difference: #{diff} (tolerance: #{tolerance}). " \
           "Running libvips #{TestHelper.libvips_version}; references were rendered with " \
           "#{TestHelper::REFERENCE_LIBVIPS}. A small difference on a different libvips is usually the build, " \
           'not a regression -- confirm on the reference version before re-baselining.'
  end
end

TestHelper.setup_tmp_dir

module Minitest
  class Test
    include TestHelper
  end
end
