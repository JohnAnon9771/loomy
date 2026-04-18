# frozen_string_literal: true

require 'test_helper'

class StackTest < Minitest::Test
  def test_vertical_stack_spacing
    reference = 'test/assets/references/vstack_spacing.png'

    # 2 blue squares (100x100) with 20px spacing
    # Total height should be 100 + 20 + 100 = 220
    # Total width should be 100
    image = Loomy.generate(size: [200, 300]) do
      vstack spacing: 20, x: 50, y: 40 do
        layer 'test/assets/blue_square.png', width: 100, height: 100
        layer 'test/assets/blue_square.png', width: 100, height: 100
      end
    end

    assert_image_similar(reference, image)
  end

  def test_horizontal_stack_alignment
    reference = 'test/assets/references/hstack_alignment.png'

    # 2 blue squares with different sizes, aligned to middle
    image = Loomy.generate(size: [400, 200]) do
      hstack spacing: 50, valign: :middle, x: 50, y: 50 do
        layer 'test/assets/blue_square.png', width: 100, height: 100
        layer 'test/assets/blue_square.png', width: 50, height: 50
      end
    end

    assert_image_similar(reference, image)
  end

  def test_nested_stacks
    reference = 'test/assets/references/nested_stacks.png'

    image = Loomy.generate(size: [500, 500]) do
      vstack spacing: 20, x: 10, y: 10 do
        hstack spacing: 10 do
          layer solid: '#ff0000', width: 50, height: 50
          layer solid: '#00ff00', width: 50, height: 50
        end
        layer solid: '#0000ff', width: 110, height: 50
      end
    end

    assert_image_similar(reference, image)
  end

  def test_stack_with_effects
    reference = 'test/assets/references/stack_effects.png'

    image = Loomy.generate(size: [200, 200]) do
      vstack spacing: 10, align: :center do
        layer solid: '#ff0000', width: 50, height: 50
        layer solid: '#00ff00', width: 50, height: 50

        # Effect on the whole stack
        blur radius: 5
      end
    end

    assert_image_similar(reference, image)
  end
end
