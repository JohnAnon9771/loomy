# frozen_string_literal: true

require 'test_helper'

# Layout is where geometry lives now. It used to be spread across
# Planner::Builder (percentages), Ops::Layer (align/valign/anchor/fill) and
# Ops::Stack (main-axis offsets), with no rule for which layer decided what.
class LayoutEngineTest < Minitest::Test
  SQUARE = 'test/assets/blue_square.png'  # 200x200
  TALL = 'test/assets/base_large.png'     # 4200x4800

  def test_declared_position_is_used_as_is
    frames, size = layout(size: [300, 300]) { layer SQUARE, x: 20, y: 30 }

    assert_equal [300, 300], size
    assert_frame({ x: 20, y: 30, width: 200, height: 200 }, frames.values.first)
  end

  def test_alignment_centres_using_the_rendered_size
    frames, = layout(size: [300, 100]) { layer SQUARE, width: 50, height: 50, align: :center }

    assert_equal 125, frames.values.first.x # (300 - 50) / 2
  end

  def test_anchor_resolves_both_axes
    frames, = layout(size: [200, 200]) { layer SQUARE, width: 50, height: 50, anchor: :bottom_right }

    frame = frames.values.first

    assert_equal [150, 150], [frame.x, frame.y]
  end

  def test_offsets_shift_an_aligned_node
    frames, = layout(size: [200, 200]) { layer SQUARE, width: 20, height: 20, align: :center, offset_x: 50 }

    assert_equal 140, frames.values.first.x # (200 - 20) / 2 + 50
  end

  def test_percentages_resolve_against_the_parent_box
    frames, = layout(size: [400, 200]) { layer SQUARE, width: '50%' }

    assert_equal 200, frames.values.first.width
  end

  def test_percentage_inside_a_sized_group_uses_the_group_box
    frames, = layout(size: [800, 800]) do
      group width: 200, height: 200 do
        layer SQUARE, width: '50%'
      end
    end

    layer_frame = frames.find { |node, _| node.is_a?(Loomy::AST::Layer) }.last

    assert_equal 100, layer_frame.width
  end

  def test_a_percentage_with_no_resolvable_parent_raises
    assert_raises(Loomy::LayoutError) do
      layout { layer SQUARE, width: '50%' }
    end
  end

  # The default fit preserves aspect ratio, so the rendered size is not
  # necessarily the requested box. Placement has to use the rendered size.
  def test_contain_fit_preserves_aspect_ratio
    frames, = layout(size: [500, 500]) { layer TALL, width: 200, height: 200 }

    frame = frames.values.first

    assert_equal [175, 200], [frame.width, frame.height] # 4200x4800 into 200x200
  end

  def test_cover_fit_fills_the_requested_box
    frames, = layout(size: [500, 500]) { layer TALL, width: 200, height: 200, fit: :cover }

    frame = frames.values.first

    assert_equal [200, 200], [frame.width, frame.height]
  end

  def test_fill_takes_the_parent_box_on_that_axis
    frames, = layout(size: [300, 100]) { layer solid: '#0f0', width: :fill, height: 50 }

    frame = frames.values.first

    assert_equal [300, 50], [frame.width, frame.height]
  end

  def test_trimmed_layers_measure_at_their_opaque_extent
    frames, size = layout { layer 'test/assets/trim_test_source.png', trim: true }

    assert_equal [100, 100], size
    assert_equal [100, 100], [frames.values.first.width, frames.values.first.height]
  end

  def test_an_auto_sized_canvas_wraps_its_children
    _frames, size = layout do
      layer SQUARE, x: 10, y: 10
      layer SQUARE, x: 100, y: 100
    end

    assert_equal [300, 300], size
  end

  def test_vertical_stack_offsets_accumulate_with_spacing
    frames, = layout(size: [200, 300]) do
      vstack spacing: 20 do
        layer SQUARE, width: 100, height: 100
        layer SQUARE, width: 100, height: 80
      end
    end

    assert_equal [0, 120], layer_frames(frames).map(&:y)
  end

  def test_horizontal_stack_offsets_accumulate_along_x
    frames, = layout(size: [400, 200]) do
      hstack spacing: 25 do
        layer SQUARE, width: 40, height: 100
        layer SQUARE, width: 60, height: 100
      end
    end

    assert_equal [0, 65], layer_frames(frames).map(&:x)
  end

  def test_stack_cross_alignment_applies_to_children
    frames, = layout(size: [200, 200]) do
      vstack align: :center do
        layer SQUARE, width: 50, height: 50
      end
    end

    assert_equal 75, layer_frames(frames).first.x # (200 - 50) / 2
  end

  def test_a_child_overrides_the_stacks_cross_alignment
    frames, = layout(size: [200, 200]) do
      vstack align: :center do
        layer SQUARE, width: 50, height: 50, align: :right
      end
    end

    assert_equal 150, layer_frames(frames).first.x
  end

  # Main-axis distribution is new. The old AST called `valign` "main-axis
  # distribution" in a comment, but it was only ever applied as cross-axis
  # alignment, so nothing of the sort existed.
  def test_main_axis_distribution_centre
    frames, = layout(size: [200, 300]) do
      vstack distribute: :center do
        layer SQUARE, width: 50, height: 50
        layer SQUARE, width: 50, height: 50
      end
    end

    assert_equal [100, 150], layer_frames(frames).map(&:y) # 300 - 100 free, half above
  end

  def test_main_axis_distribution_space_between
    frames, = layout(size: [200, 300]) do
      vstack distribute: :space_between do
        layer SQUARE, width: 50, height: 50
        layer SQUARE, width: 50, height: 50
      end
    end

    assert_equal [0, 250], layer_frames(frames).map(&:y)
  end

  def test_main_axis_distribution_end
    frames, = layout(size: [200, 300]) do
      vstack spacing: 10, distribute: :end do
        layer SQUARE, width: 50, height: 50
        layer SQUARE, width: 50, height: 50
      end
    end

    assert_equal [190, 250], layer_frames(frames).map(&:y)
  end

  private

  def layout(**options, &)
    canvas = Loomy::DSL::PipelineBuilder.new(options, &).build
    canvas = Loomy::AST::Pruner.new(canvas).call

    Loomy::Layout::Engine.new(Loomy::Render::SourceLoader.new).call(canvas)
  end

  def layer_frames(frames)
    frames.filter_map { |node, frame| frame if node.is_a?(Loomy::AST::Layer) }
  end

  def assert_frame(expected, frame)
    assert_equal expected, { x: frame.x, y: frame.y, width: frame.width, height: frame.height }
  end
end
