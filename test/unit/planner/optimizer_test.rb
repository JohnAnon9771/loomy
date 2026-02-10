require "test_helper"
require "loomy/ops/load"
require "loomy/ops/resize"
require "loomy/ops/trim"
require "loomy/planner/optimizer"

class PlannerOptimizerTest < Minitest::Test
  def test_smart_load_injection
    # Scenario: Load -> Resize
    load_op = Loomy::Ops::Load.new("test.png")
    resize_op = Loomy::Ops::Resize.new(input: load_op, width: 100, height: 100, fit: :cover)
    
    optimizer = Loomy::Planner::Optimizer.new
    optimizer.optimize(resize_op)
    
    # Check if target dimensions were pushed down to Load op
    assert_equal 100, load_op.target_width
    assert_equal 100, load_op.target_height
    assert_equal :centre, load_op.crop_mode
  end

  def test_smart_load_with_trim
    # Scenario: Load -> Trim -> Resize(Small)
    load_op = Loomy::Ops::Load.new("test.png")
    trim_op = Loomy::Ops::Trim.new(input: load_op)
    resize_op = Loomy::Ops::Resize.new(input: trim_op, width: 50, height: 50) # Small target
    
    optimizer = Loomy::Planner::Optimizer.new
    optimizer.optimize(resize_op)
    
    # Check if Load was optimized to load a safe thumbnail
    # Logic: width * 2 = 100
    assert_equal 100, load_op.target_width
    assert_nil load_op.crop_mode # Should not crop, as we need to trim
  end
end
