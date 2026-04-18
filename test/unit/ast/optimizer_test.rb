require "test_helper"
require "loomy/dsl/pipeline_builder"
require "loomy/ast/optimizer"

class OptimizerTest < Minitest::Test
  def test_pruning_empty_sources
    canvas = Loomy::AST::Canvas.new(size: [100, 100])

    layer1 = Loomy::AST::Layer.new(font: "Arial")
    layer2 = Loomy::AST::Layer.new(text: "", size: 20)
    layer3 = Loomy::AST::Layer.new(source: "")
    layer4 = Loomy::AST::Layer.new(source: "bar.png")

    canvas.add_child(layer1)
    canvas.add_child(layer2)
    canvas.add_child(layer3)
    canvas.add_child(layer4)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 1, canvas.children.size, "Only 1 valid layer should remain"
    assert_equal "bar.png", canvas.children.first.source
  end

  def test_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    layer = Loomy::AST::Layer.new(source: "foo.png")

    layer.add_effect(Loomy::AST::Effects::Blur.new(radius: 0))
    layer.add_effect(Loomy::AST::Effects::Lighting.new(strength: 0))
    layer.add_effect(Loomy::AST::Effects::ColorAdjustment.new(brightness: 1.0, contrast: 1.0))
    layer.add_effect(Loomy::AST::Effects::Blur.new(radius: 5))

    canvas.add_child(layer)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 1, layer.effects.size
    assert_equal 5, layer.effects.first.radius
  end
end