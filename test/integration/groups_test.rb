# frozen_string_literal: true

require 'test_helper'

class GroupsTest < Minitest::Test
  def test_nested_groups_and_effects
    reference = 'test/assets/references/groups_output.png'

    image = Loomy.generate(size: [400, 400]) do
      group x: 50, y: 50 do
        layer 'test/assets/blue_square.png', width: 100, height: 100
        layer 'test/assets/blue_square.png', x: 20, y: 20, width: 100, height: 100 do
          blur radius: 5
        end

        # Group-level effect
        blur radius: 2
      end

      layer 'test/assets/blue_square.png', x: 200, y: 200, width: 50, height: 50 do
        grayscale
      end
    end

    # Nested blur over a composite resamples slightly differently between
    # libvips builds; the slack applies only off the reference version.
    assert_image_similar(reference, image, across_libvips: 0.5)
  end
end
