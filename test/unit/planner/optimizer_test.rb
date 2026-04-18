require "test_helper"
require "loomy/ops/load"
require "loomy/ops/resize"
require "loomy/ops/trim"
require "loomy/planner/optimizer"

class PlannerOptimizerTest < Minitest::Test
  def test_smart_load_injection
    load_op = Loomy::Ops::Load.new("test.png")
    resize_op = Loomy::Ops::Resize.new(input: load_op, width: 100, height: 100, fit: :cover)

    optimizer = Loomy::Planner::Optimizer.new
    result = optimizer.optimize(resize_op)

    assert_equal 100, result.target_width
    assert_equal 100, result.target_height
    assert_equal :centre, result.crop_mode
  end

  def test_smart_load_with_trim
    load_op = Loomy::Ops::Load.new("test.png")
    trim_op = Loomy::Ops::Trim.new(input: load_op)
    resize_op = Loomy::Ops::Resize.new(input: trim_op, width: 50, height: 50)

    optimizer = Loomy::Planner::Optimizer.new
    result = optimizer.optimize(resize_op)

    assert_equal 100, result.target_width
    assert_nil result.crop_mode
  end

  def test_no_optimization_when_no_resize
    load_op = Loomy::Ops::Load.new("test.png")

    optimizer = Loomy::Planner::Optimizer.new
    result = optimizer.optimize(load_op)

    assert_same load_op, result
  end
end