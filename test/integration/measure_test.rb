# frozen_string_literal: true

require 'test_helper'

# A measurement is only worth having if it is where the pixels go. Each case
# renders the same block it measured and reads the opaque extent back.
class MeasureTest < Minitest::Test
  TALL = 'test/assets/base_large.png' # opaque, 4200x4800

  def test_a_contained_image_is_drawn_exactly_where_it_was_measured
    assert_measured_where_drawn do
      group x: 300, y: 100, width: 400, height: 400 do
        layer TALL, width: 400, height: 400, align: :center, valign: :middle, name: :subject
      end
    end
  end

  def test_an_anchored_layer_in_a_stack_is_drawn_where_it_was_measured
    assert_measured_where_drawn do
      hstack x: 50, y: 60, height: 200, spacing: 10, valign: :bottom do
        layer solid: '#00000000', width: 40, height: 40
        layer solid: '#f00', width: 30, height: 70, name: :subject
      end
    end
  end

  private

  def assert_measured_where_drawn(&)
    measured = Loomy.measure(size: [800, 600], &).fetch(:subject)
    image = Loomy.generate(size: [800, 600], &)

    assert_equal [measured.x, measured.y, measured.width, measured.height], opaque_extent(image)
  end

  def opaque_extent(image)
    alpha = image.extract_band(image.bands - 1)

    alpha.find_trim(background: [0], threshold: 0.5)
  end
end
