# frozen_string_literal: true

require 'test_helper'
require 'loomy/dsl/pipeline_builder'
require 'loomy/ast/optimizer'
require 'loomy/planner/builder'

class OptimizerTest < Minitest::Test
  def test_pruning_invalid_layers
    canvas = Loomy::AST::Canvas.new(size: [100, 100])

    layer1 = Loomy::AST::Layer.new(source: 'foo.png')
    layer2 = Loomy::AST::Layer.new(font: 'Arial')
    layer3 = Loomy::AST::Layer.new(text: '', size: 20)
    layer4 = Loomy::AST::Layer.new(source: '')
    layer5 = Loomy::AST::Layer.new(source: 'bar.png')

    canvas.add_child(layer1)
    canvas.add_child(layer2)
    canvas.add_child(layer3)
    canvas.add_child(layer4)
    canvas.add_child(layer5)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 2, canvas.children.size, 'Only foo.png and bar.png should remain'
    sources = canvas.children.map(&:source)
    assert_includes sources, 'foo.png'
    assert_includes sources, 'bar.png'
  end

  def test_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])
    layer = Loomy::AST::Layer.new(source: 'foo.png')

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

  def test_displacement_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])

    layer1 = Loomy::AST::Layer.new(source: 'a.png')
    layer1.add_effect(Loomy::AST::Effects::Displacement.new(scale: 0))

    layer2 = Loomy::AST::Layer.new(source: 'b.png')
    layer2.add_effect(Loomy::AST::Effects::Displacement.new(map: 'map.png', scale: 10))

    canvas.add_child(layer1)
    canvas.add_child(layer2)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 0, layer1.effects.size, 'Effect with scale 0 should be pruned'
    assert_equal 1, layer2.effects.size, 'Effect with valid scale should remain'
  end

  def test_lighting_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])

    layer1 = Loomy::AST::Layer.new(source: 'a.png')
    layer1.add_effect(Loomy::AST::Effects::Lighting.new(strength: 0))

    layer2 = Loomy::AST::Layer.new(source: 'b.png')
    layer2.add_effect(Loomy::AST::Effects::Lighting.new(map: 'map.png', strength: 1.0))

    canvas.add_child(layer1)
    canvas.add_child(layer2)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 0, layer1.effects.size, 'Effect with strength 0 should be pruned'
    assert_equal 1, layer2.effects.size, 'Effect with valid strength should remain'
  end

  def test_mask_displacement_effect_pruning
    canvas = Loomy::AST::Canvas.new(size: [100, 100])

    layer1 = Loomy::AST::Layer.new(source: 'a.png')
    layer1.add_effect(Loomy::AST::Effects::Displacement.new(from_mask: 'mask.png', intensity: 0))

    layer2 = Loomy::AST::Layer.new(source: 'b.png')
    layer2.add_effect(Loomy::AST::Effects::Displacement.new(from_mask: 'mask.png', intensity: 1.0))

    canvas.add_child(layer1)
    canvas.add_child(layer2)

    optimizer = Loomy::AST::Optimizer.new(canvas)
    optimizer.call

    assert_equal 0, layer1.effects.size, 'Effect with zero intensity should be pruned'
    assert_equal 1, layer2.effects.size, 'Effect with valid intensity should remain'
  end
end