# frozen_string_literal: true

require 'loomy'
require 'minitest/autorun'
require 'vips'
require 'fileutils'

# Fixtures under test/assets are committed binaries, not generated at run time:
# they are the inputs the golden references were produced from, so regenerating
# them would move every golden. test/fixtures_test.rb pins their contract.
module TestHelper
  TMP_DIR = 'test/tmp'

  MISSING_REFERENCE = <<~MSG
    Reference image not found: %s

    If this is a new golden test, generate the baseline deliberately:

        bundle exec rake test:baseline

    Then inspect the generated PNG before committing it. References are the
    visual contract of the suite and must never appear as a side effect of an
    ordinary test run.
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
      rewrite_reference(expected_path, actual)
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

  private

  # PNG encoding is not byte-stable, so rewriting a golden whose pixels have not
  # moved still leaves a modified file behind. A baseline run then reports every
  # reference as changed and buries the one that really moved, which is exactly
  # the diff the developer is being asked to review. Leave untouched goldens
  # untouched so `git status test/assets/references` names only the real change.
  #
  # The candidate is encoded first and compared from disk: renders are float and
  # goldens are 8-bit PNG, so comparing the in-memory image against its own
  # reference reports the quantisation of the write as a difference. What decides
  # the rewrite is whether the committed pixels would change.
  def rewrite_reference(path, actual)
    FileUtils.mkdir_p(File.dirname(path))
    return actual.write_to_file(path) unless File.exist?(path)

    candidate = tmp_path("baseline-#{File.basename(path)}")
    actual.write_to_file(candidate)

    if identical_pixels?(Vips::Image.new_from_file(path), Vips::Image.new_from_file(candidate))
      FileUtils.rm_f(candidate)
    else
      FileUtils.mv(candidate, path)
    end
  end

  # Exact identity, not the assertion tolerance: a golden is the pixels it
  # records, so anything that moves at all is a change worth writing out.
  def identical_pixels?(expected, actual)
    return false unless expected.width == actual.width &&
                        expected.height == actual.height &&
                        expected.bands == actual.bands

    (expected.cast(:float) - actual.cast(:float)).abs.max.zero?
  end
end

TestHelper.setup_tmp_dir

module Minitest
  class Test
    include TestHelper
  end
end
