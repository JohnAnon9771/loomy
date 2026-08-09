# frozen_string_literal: true

require 'test_helper'

class PrunerTest < Minitest::Test
  def test_pruning_layers_without_a_usable_source
    canvas = Loomy::AST::Canvas.new({ size: [100, 100] }, [
                                      Loomy::AST::Layer.new(font: 'Arial'),
                                      Loomy::AST::Layer.new(text: '', size: 20),
                                      Loomy::AST::Layer.new(source: ''),
                                      Loomy::AST::Layer.new(source: 'bar.png')
                                    ])

    pruned = Loomy::AST::Pruner.new(canvas).call

    assert_equal 1, pruned.children.size
    assert_equal 'bar.png', pruned.children.first.source
  end

  def test_pruning_no_op_effects
    layer = Loomy::AST::Layer.new({ source: 'foo.png' }, [], [
                                    Loomy::AST::Effects::Blur.new(radius: 0),
                                    Loomy::AST::Effects::Lighting.new(strength: 0),
                                    Loomy::AST::Effects::ColorAdjustment.new(brightness: 1.0, contrast: 1.0),
                                    Loomy::AST::Effects::Blur.new(radius: 5)
                                  ])
    canvas = Loomy::AST::Canvas.new({ size: [100, 100] }, [layer])

    pruned = Loomy::AST::Pruner.new(canvas).call
    effects = pruned.children.first.effects

    assert_equal 1, effects.size
    assert_equal 5, effects.first.radius
  end

  # Two values that look neutral and are not. Under the old maths `contrast`
  # and `brightness` collapsed into one gain, so 2.0 and 0.5 really did cancel;
  # contrast pivots around mid-grey now, so they do not. A negative lighting
  # strength inverts the map rather than switching the light off.
  def test_effects_that_only_look_neutral_survive
    layer = Loomy::AST::Layer.new({ source: 'foo.png' }, [], [
                                    Loomy::AST::Effects::ColorAdjustment.new(brightness: 2.0, contrast: 0.5),
                                    Loomy::AST::Effects::Lighting.new(map: 'm.png', strength: -1.0)
                                  ])
    canvas = Loomy::AST::Canvas.new({ size: [100, 100] }, [layer])

    pruned = Loomy::AST::Pruner.new(canvas).call

    assert_equal 2, pruned.children.first.effects.size
  end

  # Pruning must be open to effects it does not know about.
  def test_custom_effects_participate_in_pruning
    dimmer = Class.new(Loomy::AST::Effect) do
      def amount = properties[:amount]
      def no_op? = amount.zero?
    end

    layer = Loomy::AST::Layer.new({ source: 'foo.png' }, [], [
                                    dimmer.new(amount: 0),
                                    dimmer.new(amount: 3)
                                  ])
    canvas = Loomy::AST::Canvas.new({ size: [10, 10] }, [layer])

    pruned = Loomy::AST::Pruner.new(canvas).call
    effects = pruned.children.first.effects

    assert_equal 1, effects.size
    assert_equal 3, effects.first.amount
  end

  def test_containers_left_empty_are_dropped
    canvas = Loomy::AST::Canvas.new({ size: [100, 100] }, [
                                      Loomy::AST::Group.new({ x: 10 }, [Loomy::AST::Layer.new(source: '')]),
                                      Loomy::AST::Group.new({ x: 20 }, [Loomy::AST::Layer.new(source: 'ok.png')])
                                    ])

    pruned = Loomy::AST::Pruner.new(canvas).call

    assert_equal 1, pruned.children.size
    assert_equal 20, pruned.children.first.x
  end

  def test_pruning_leaves_the_input_tree_untouched
    layer = Loomy::AST::Layer.new({ source: 'foo.png' }, [], [Loomy::AST::Effects::Blur.new(radius: 0)])
    canvas = Loomy::AST::Canvas.new({ size: [10, 10] }, [layer, Loomy::AST::Layer.new(source: '')])

    Loomy::AST::Pruner.new(canvas).call

    assert_equal 2, canvas.children.size, 'pruning must not mutate the tree it was given'
    assert_equal 1, layer.effects.size
  end

  def test_nodes_are_frozen
    layer = Loomy::AST::Layer.new(source: 'foo.png')

    assert_predicate layer.properties, :frozen?
    assert_predicate layer.children, :frozen?
    assert_predicate layer.effects, :frozen?
  end
end
