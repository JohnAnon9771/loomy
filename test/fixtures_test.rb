# frozen_string_literal: true

require 'test_helper'

# The committed fixtures under test/assets are the inputs every golden reference
# was rendered from. If one changes, the goldens move with it and the failure
# surfaces as an unrelated visual regression somewhere else.
#
# Pinning their contract here makes fixture drift fail loudly, and in one place.
class FixturesTest < Minitest::Test
  FIXTURES = {
    'base.png' => { size: [500, 500], bands: 4, corner: [255, 0, 0, 255] },
    'base_large.png' => { size: [4200, 4800], bands: 4, corner: [50, 50, 50, 255] },
    'blue_square.png' => { size: [200, 200], bands: 4, corner: [0, 0, 255, 255] },
    'overlay.png' => { size: [500, 500], bands: 4, corner: [255, 0, 0, 255] },
    'overlay_large.png' => { size: [2000, 2000], bands: 4, corner: [0, 255, 0, 255] },
    'grid.png' => { size: [200, 200], bands: 4, corner: [128, 128, 128, 255] },
    'disp_map.png' => { size: [200, 200], bands: 1, corner: [50] },
    # Structured fixtures for the effect tests: a flat field cannot tell a
    # working blur from a missing one.
    'pattern.png' => { size: [200, 200], bands: 4, corner: [30, 0, 90, 255] },
    'pattern_map.png' => { size: [200, 200], bands: 3, corner: [0, 0, 0] },
    # 200x100 of pixels carrying EXIF orientation 6, so it is 100x200 upright.
    'exif_rotated.jpg' => { size: [200, 100], bands: 3, orientation: 6 },
    # 500x500, transparent, with a 100x100 opaque red square centred at 200,200.
    'trim_test_source.png' => { size: [500, 500], bands: 4, corner: [0, 0, 0, 0], centre: [255, 0, 0, 255] }
  }.freeze

  FIXTURES.each do |name, spec|
    define_method("test_fixture_#{name.sub('.png', '')}") do
      path = File.join('test/assets', name)

      assert_path_exists path, "Missing committed fixture #{path}"

      image = Vips::Image.new_from_file(path)

      assert_equal spec[:size], [image.width, image.height], "#{name} has the wrong dimensions"
      assert_equal spec[:bands], image.bands, "#{name} has the wrong band count"
      if spec[:corner]
        assert_equal spec[:corner], image.getpoint(0, 0).map(&:to_i), "#{name} has the wrong top-left pixel"
      end

      if spec[:orientation]
        assert_equal spec[:orientation], image.get('orientation'), "#{name} has the wrong EXIF orientation"
      end

      return unless spec[:centre]

      assert_equal spec[:centre], image.getpoint(image.width / 2, image.height / 2).map(&:to_i),
                   "#{name} has the wrong centre pixel"
    end
  end

  def test_no_test_writes_into_the_assets_directory
    # A test that regenerates a fixture it also asserts against can never fail.
    generators = Dir['test/**/*.rb'].select do |file|
      File.read(file).match?(%r{write_to_file\(?\s*['"]test/assets})
    end

    assert_empty generators,
                 "Tests must not write into test/assets (fixtures and goldens are committed): #{generators.join(', ')}"
  end
end
