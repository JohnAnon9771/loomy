# frozen_string_literal: true

require 'test_helper'

class EffectsRegistrationTest < Minitest::Test
  # The DSL validates a lighting type against Lighting::TYPES and the processor
  # looks the same type up in LIGHT_BLENDS. One that lived in only one of them
  # would pass validation and then raise KeyError half-way through a render.
  def test_every_lighting_type_has_a_blend
    assert_equal Loomy::AST::Effects::Lighting::TYPES.sort,
                 Loomy::EffectsRegistration::LIGHT_BLENDS.keys.sort
  end

  # Both blends are the identity where the map is mid-grey, which is what lets
  # strength scale the map instead of blending two images.
  def test_strength_flattens_the_map_towards_mid_grey
    map = Vips::Image.new_from_file('test/assets/pattern_map.png')

    flattened = Loomy::EffectsRegistration.lighting_map(map, 0)
    unchanged = Loomy::EffectsRegistration.lighting_map(map, 1)

    assert_equal 128.0, flattened.min
    assert_equal 128.0, flattened.max
    assert_in_delta 0.0, (map.cast(:float) - unchanged.cast(:float)).abs.max, 0.001
  end
end
