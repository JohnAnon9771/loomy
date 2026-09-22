# frozen_string_literal: true

require 'test_helper'

# Loomy.measure answers where a named node lands, in canvas coordinates,
# without rendering anything.
class MeasurementTest < Minitest::Test
  SQUARE = 'test/assets/blue_square.png'  # 200x200
  TALL = 'test/assets/base_large.png'     # 4200x4800

  def test_frames_are_in_canvas_coordinates_through_nested_containers
    result = Loomy.measure(size: [500, 500]) do
      group x: 100, y: 50, width: 300, height: 300 do
        group x: 20, y: 30, width: 100, height: 100, name: :inner do
          layer solid: '#f00', width: 10, height: 10, anchor: :bottom_right, name: :dot
        end
      end
    end

    assert_equal frame(120, 80, 100, 100), result.fetch(:inner)
    assert_equal frame(210, 170, 10, 10), result.fetch(:dot)
  end

  def test_stack_children_are_offset_by_the_stack
    result = Loomy.measure(size: [300, 300]) do
      vstack x: 40, y: 10, spacing: 5 do
        layer solid: '#f00', width: 20, height: 20
        layer solid: '#0f0', width: 20, height: 20, name: :second
      end
    end

    assert_equal frame(40, 35, 20, 20), result.fetch(:second)
  end

  # The case the issue came from: a contain-fit image centred in a region
  # touches one pair of edges and sits inside the other.
  def test_a_contained_image_reports_the_box_it_is_drawn_in
    result = Loomy.measure(size: [800, 600]) do
      group x: 300, y: 100, width: 400, height: 400 do
        layer TALL, width: 400, height: 400, align: :center, valign: :middle, name: :art
      end
    end

    assert_equal frame(325, 100, 350, 400), result.fetch(:art) # 4200x4800 contained in 400x400
  end

  def test_only_named_nodes_are_reported
    result = Loomy.measure(size: [100, 100]) do
      layer SQUARE
      layer solid: '#f00', name: :plate
    end

    assert_equal [:plate], result.to_h.keys
  end

  def test_the_canvas_size_is_reported_even_when_it_was_derived
    result = Loomy.measure { layer SQUARE, x: 10, y: 20 }

    assert_equal [210, 220], result.size
  end

  def test_a_pruned_node_has_no_frame_and_says_why
    result = Loomy.measure(size: [100, 100]) { layer text: '', name: :caption }

    assert_nil result[:caption]
    error = assert_raises(Loomy::UnknownNode) { result.fetch(:caption) }
    assert_match(/pruned/, error.message)
  end

  def test_an_undeclared_name_lists_what_was_measured
    result = Loomy.measure(size: [100, 100]) { layer solid: '#f00', name: :plate }

    error = assert_raises(Loomy::UnknownNode) { result.fetch(:plaet) }
    assert_match(/never declared.*:plate/, error.message)
  end

  # Checked against the declared tree, so a duplicate is refused even when one
  # of the pair is pruned and could never have been measured.
  def test_a_name_used_twice_is_refused
    assert_raises(Loomy::DuplicateName) do
      Loomy.measure(size: [100, 100]) do
        layer solid: '#f00', name: :plate
        group { layer text: '', name: :plate }
      end
    end
  end

  def test_name_accepts_a_symbol_or_a_string_on_every_positioned_node
    result = Loomy.measure(size: [100, 100]) do
      layer solid: '#f00', name: :plate
      group(name: 'panel') { layer solid: '#f00' }
      vstack(name: :column) { layer solid: '#f00' }
    end

    assert_equal [:plate, 'panel', :column], result.to_h.keys
  end

  def test_name_rejects_anything_else
    [123, '', [:a]].each do |value|
      assert_raises(Loomy::InvalidValue) { Loomy.measure { layer solid: '#f00', name: value } }
    end
  end

  def test_the_result_is_frozen
    result = Loomy.measure(size: [100, 100]) { layer solid: '#f00', name: :plate }

    assert_predicate result, :frozen?
    assert_predicate result.to_h, :frozen?
  end

  private

  def frame(left, top, width, height) = Loomy::Layout::Frame.new(x: left, y: top, width: width, height: height)
end
