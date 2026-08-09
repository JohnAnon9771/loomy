# frozen_string_literal: true

require 'test_helper'

class AccessPlanTest < Minitest::Test
  SOURCE = 'test/assets/base.png'
  OTHER = 'test/assets/overlay.png'
  MAP = 'test/assets/disp_map.png'

  def test_a_source_read_once_can_stream
    plan = streamable { layer SOURCE }

    assert_equal [SOURCE].to_set, plan
  end

  # Two layers over one file is two passes over one handle.
  def test_a_source_behind_two_layers_cannot_stream
    plan = streamable do
      layer SOURCE
      layer SOURCE, x: 10
    end

    assert_empty plan
  end

  def test_a_source_that_is_also_an_effect_map_cannot_stream
    plan = streamable do
      layer SOURCE
      layer OTHER do
        displace map: SOURCE, scale: 5
      end
    end

    refute_includes plan, SOURCE
  end

  # find_trim consumes the whole image in the measure pass, and the render then
  # reads it again from the top.
  def test_a_trimmed_source_cannot_stream
    plan = streamable { layer SOURCE, trim: true }

    assert_empty plan
  end

  # mapim indexes its input out of order.
  def test_a_displaced_source_cannot_stream
    plan = streamable do
      layer SOURCE do
        displace map: MAP, scale: 5
      end
    end

    assert_equal [MAP].to_set, plan
  end

  # The effect sits on the group, but the out-of-order read reaches every file
  # underneath it.
  def test_displacement_on_a_container_disqualifies_its_children
    plan = streamable do
      group do
        layer SOURCE
        displace map: MAP, scale: 5
      end
    end

    refute_includes plan, SOURCE
  end

  def test_generated_sources_are_never_named
    plan = streamable do
      layer solid: '#f00', width: 10, height: 10
      layer gradient: %w[#000 #fff], width: 10, height: 10
      layer text: 'hi', size: 12
    end

    assert_empty plan
  end

  private

  def streamable(&)
    sources = Loomy::Render::SourceCache.new
    canvas = Loomy::DSL::PipelineBuilder.new(sources, { size: [200, 200] }, &).build

    Loomy::Render::AccessPlan.streamable(Loomy::AST::Pruner.new(canvas).call)
  end
end
