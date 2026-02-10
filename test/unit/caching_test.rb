require "test_helper"
require "loomy/ops/load"

class CachingTest < Minitest::Test
  def test_load_caching
    path = "test/assets/base.png"
    op = Loomy::Ops::Load.new(path)
    
    context = { source_cache: {} }
    
    img1 = op.call(context)
    img2 = op.call(context)
    
    # Check that they are the exact same object (from cache)
    assert_same img1, img2
    assert_equal 1, context[:source_cache].size
  end

  def test_cache_keys_differ_by_params
    path = "test/assets/base.png"
    
    # Op 1: Raw
    op1 = Loomy::Ops::Load.new(path)
    
    # Op 2: With Target Size
    op2 = Loomy::Ops::Load.new(path, target_width: 100, target_height: 100)
    
    context = { source_cache: {} }
    
    img1 = op1.call(context)
    img2 = op2.call(context)
    
    # Should be different objects and different cache entries
    refute_same img1, img2
    assert_equal 2, context[:source_cache].size
  end
end
