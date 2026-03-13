require "test_helper"
require "loomy/dsl/pipeline_builder"
require "loomy/ast/optimizer"

class OptimizerTest < Minitest::Test
  def test_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    
    # Layer 1: width 0
    layer1 = Loomy::AST::Layer.new(source: "foo.png", width: 0)
    
    # Layer 2: No source
    layer2 = Loomy::AST::Layer.new(font: "Arial")
    
    # Layer 3: Empty text
    layer3 = Loomy::AST::Layer.new(text: "", size: 20)
    
    # Layer 4: Empty source file
    layer4 = Loomy::AST::Layer.new(source: "")
    
    # Layer 5: Valid
    layer5 = Loomy::AST::Layer.new(source: "bar.png")
    
    canvas.add_child(layer1)
    canvas.add_child(layer2)
    canvas.add_child(layer3)
    canvas.add_child(layer4)
    canvas.add_child(layer5)
    
    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call
    
    assert_equal 1, canvas.children.size, "Only 1 valid layer should remain"
    assert_equal "bar.png", canvas.children.first.source
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
