require "test_helper"
require "loomy/dsl/pipeline_builder"
require "loomy/ast/optimizer"

class OptimizerTest < Minitest::Test
  def test_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    layer = Loomy::AST::Layer.new(source: "foo.png", width: 0)
    canvas.add_child(layer)
    
    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call
    
    assert_empty canvas.children, "Layer with width 0 should be pruned"
  end

  def test_relative_geometry
    canvas = Loomy::AST::Canvas.new(size: [200, 100]) # 200w, 100h
    
    # Layer 1: 50% width -> 100
    # Layer 2: 10% x -> 20
    
    layer1 = Loomy::AST::Layer.new(source: "l1.png", width: "50%", height: "100%")
    layer2 = Loomy::AST::Layer.new(source: "l2.png", x: "10%", y: "50%")
    
    canvas.add_child(layer1)
    canvas.add_child(layer2)
    
    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call
    
    assert_equal 100, layer1.width
    assert_equal 100, layer1.height
    
    assert_equal 20, layer2.x
    assert_equal 50, layer2.y
  end

  def test_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    layer = Loomy::AST::Layer.new(source: "foo.png")
    
    # These should be removed
    layer.add_effect(Loomy::AST::Effects::Blur.new(radius: 0))
    layer.add_effect(Loomy::AST::Effects::Lighting.new(strength: 0))
    layer.add_effect(Loomy::AST::Effects::ColorAdjustment.new(brightness: 1.0, contrast: 1.0))
    
    # This should stay
    layer.add_effect(Loomy::AST::Effects::Blur.new(radius: 5))

    canvas.add_child(layer)
    
    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call
    
    assert_equal 1, layer.effects.size
    assert_equal 5, layer.effects.first.radius
  end
end
