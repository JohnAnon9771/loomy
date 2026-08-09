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

  def assert_image_similar(expected_path, actual_image, tolerance: 0.1)
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
           "Image similarity failed for #{expected_path}. Mean difference: #{diff} (tolerance: #{tolerance})"
  end
end

TestHelper.setup_tmp_dir

module Minitest
  class Test
    include TestHelper
  end
end
