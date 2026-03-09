require "test_helper"

class MockOp < Loomy::Ops::Base
  attr_reader :w, :h
  def initialize(w, h)
    super()
    @w, @h = w, h
  end

  def call(context = nil)
    Vips::Image.black(@w, @h, bands: 3).bandjoin(255).copy(interpretation: :srgb)
  end
end

class OpsStackTest < Minitest::Test
  def test_vertical_layout_coordinates
    stack = Loomy::Ops::Stack.new(direction: :vertical, spacing: 10, background_width: 200, background_height: 300)
    
    # Add two layers
    stack.add_layer(MockOp.new(100, 50), {})
    stack.add_layer(MockOp.new(100, 80), {})
    
    # We need to call it to trigger layout_layers
    # Since it's an Op, we can call it.
    # To verify the internal state, we can look at @layers (it's protected in Pipeline, but we can use send)
    
    stack.call
    
    layers = stack.layers
    
    assert_equal 0, layers[0].props[:y], "First layer should be at y=0"
    assert_equal 60, layers[1].props[:y], "Second layer should be at y = height(1) + spacing = 50 + 10 = 60"
  end

  def test_horizontal_layout_coordinates
    stack = Loomy::Ops::Stack.new(direction: :horizontal, spacing: 25, background_width: 400, background_height: 200)
    
    stack.add_layer(MockOp.new(40, 100), {})
    stack.add_layer(MockOp.new(60, 100), {})
    
    stack.call
    
    layers = stack.layers
    
    assert_equal 0, layers[0].props[:x], "First layer should be at x=0"
    assert_equal 65, layers[1].props[:x], "Second layer should be at x = width(1) + spacing = 40 + 25 = 65"
  end

  def test_cross_axis_alignment_inheritance
    # Testing if align property in vstack is passed down to children props
    stack = Loomy::Ops::Stack.new(direction: :vertical, align: :center, background_width: 100, background_height: 100)
    
    stack.add_layer(MockOp.new(50, 50), {})
    stack.call
    
    layers = stack.layers
    assert_equal :center, layers[0].props[:align]
  end
end
