# frozen_string_literal: true

require 'test_helper'

# One test per defect the restructure was meant to close, so none of them can
# come back quietly.
class RegressionTest < Minitest::Test
  SOURCE = 'test/assets/blue_square.png'
  LARGE = 'test/assets/base_large.png' # 4200x4800

  # Ops::Stack wrote :y and :align straight into the property hash it shared by
  # reference with the AST node, so rendering a tree changed it.
  def test_rendering_does_not_mutate_the_tree
    canvas = Loomy::DSL::PipelineBuilder.new({ size: [300, 300] }) do
      vstack spacing: 10, align: :center do
        layer SOURCE, width: 50, height: 50
        layer SOURCE, width: 50, height: 50
      end
    end.build

    before = snapshot(canvas)
    2.times { Loomy::Render::Pipeline.new(canvas).call }

    assert_equal before, snapshot(canvas)
  end

  def test_the_same_tree_renders_identically_twice
    canvas = Loomy::DSL::PipelineBuilder.new({ size: [200, 200] }) do
      vstack spacing: 5 do
        layer SOURCE, width: 40, height: 40
        layer SOURCE, width: 40, height: 40
      end
    end.build

    first = Loomy::Render::Pipeline.new(canvas).call.write_to_memory
    second = Loomy::Render::Pipeline.new(canvas).call.write_to_memory

    assert_equal first, second
  end

  # Layout resolves the final size of every node before anything is loaded, so
  # a layer nested in a group is loaded at its target size, not its natural one.
  def test_nested_layers_are_loaded_at_their_final_size
    loader = RecordingLoader.new(Loomy::Render::SourceLoader.new)

    canvas = Loomy::DSL::PipelineBuilder.new({ size: [1000, 1000] }) do
      group x: 100, y: 100, width: 400, height: 400 do
        layer LARGE, width: 200, height: 200
      end
    end.build

    frames, size = Loomy::Layout::Engine.new(loader).call(canvas)
    Loomy::Render::Renderer.new(
      frames: frames, canvas_size: size, loader: loader,
      effects: Loomy::Render::EffectRegistry.snapshot
    ).call(canvas)

    # base_large.png is 4200x4800, so contain-fitting it into 200x200 gives
    # 175x200. The point is that the loader is asked for that, not for the
    # natural 4200x4800 with a resize bolted on afterwards.
    assert_equal [[175, 200]], loader.requested_sizes
  end

  # CanvasBuilder and Bounds lived in dsl/pipeline_builder.rb, which Zeitwerk
  # maps to PipelineBuilder, so neither constant was reachable on its own.
  def test_every_public_constant_autoloads
    assert_kind_of Class, Loomy::DSL::CanvasBuilder
    assert_kind_of Class, Loomy::Bounds
    assert_kind_of Class, Loomy::Layout::Engine
    assert_kind_of Class, Loomy::Render::SourceLoader
  end

  # The DSL accepted a layer nested in a layer, put it in the AST, and the
  # planner then dropped it without a word.
  def test_nesting_in_a_leaf_layer_fails_loudly
    assert_raises(Loomy::UnknownProperty) do
      Loomy.generate(size: [100, 100]) do
        layer SOURCE do
          layer SOURCE
        end
      end
    end
  end

  def test_to_blob_keeps_dpi
    blob = Loomy.to_blob('.png', size: [50, 50], dpi: 150) { layer SOURCE }

    assert_in_delta 150.0 / 25.4, Vips::Image.new_from_buffer(blob, '').xres, 0.001
  end

  def test_a_custom_effect_can_declare_itself_a_no_op
    always_off = Class.new(Loomy::AST::Effect) { def no_op? = true }
    canvas = Loomy::AST::Canvas.new(
      { size: [10, 10] },
      [Loomy::AST::Layer.new({ source: SOURCE }, [], [always_off.new])]
    )

    pruned = Loomy::AST::Pruner.new(canvas).call

    assert_empty pruned.children.first.effects
  end

  def test_an_unparseable_colour_fails_instead_of_rendering_black
    assert_raises(Loomy::InvalidColor) do
      Loomy.generate(size: [10, 10]) { layer solid: '#nothex' }.write_to_memory
    end
  end

  def test_a_missing_source_names_the_file
    error = assert_raises(Loomy::SourceNotFound) do
      Loomy.generate(size: [10, 10]) { layer 'test/assets/does_not_exist.png' }
    end

    assert_match(/does_not_exist\.png/, error.message)
  end

  private

  def snapshot(node)
    {
      properties: node.properties,
      children: node.children.map { |child| snapshot(child) },
      effects: node.effects.map(&:properties)
    }
  end

  # Records the sizes the renderer actually asks for.
  class RecordingLoader
    attr_reader :requested_sizes

    def initialize(loader)
      @loader = loader
      @requested_sizes = []
    end

    def load(path, width: nil, height: nil, fit: :contain)
      @requested_sizes << [width, height]
      @loader.load(path, width: width, height: height, fit: fit)
    end

    def load_trimmed(path, **options)
      @requested_sizes << [options[:width], options[:height]]
      @loader.load_trimmed(path, **options)
    end

    def dimensions(path) = @loader.dimensions(path)
    def trim_bounds(path) = @loader.trim_bounds(path)
  end
end
