# frozen_string_literal: true

require 'test_helper'

# Properties that are easy to lose again, each one pinned.
class RegressionTest < Minitest::Test
  SOURCE = 'test/assets/blue_square.png'
  LARGE = 'test/assets/base_large.png' # 4200x4800

  # Rendering reads the tree; it must never write to it.
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

  # A layer nested in a group must still be loaded at its target size.
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

    # base_large.png is 4200x4800; contained into 200x200 that is 175x200.
    assert_equal [[175, 200]], loader.requested_sizes
  end

  # Every constant a caller touches has to resolve from `require "loomy"` alone.
  def test_every_public_constant_autoloads
    assert_kind_of Class, Loomy::DSL::CanvasBuilder
    assert_kind_of Class, Loomy::Bounds
    assert_kind_of Class, Loomy::Layout::Engine
    assert_kind_of Class, Loomy::Render::SourceLoader
  end

  # Anything the DSL accepts must reach the output, or be rejected outright.
  def test_nesting_in_a_leaf_layer_fails_loudly
    assert_raises(Loomy::UnknownProperty) do
      Loomy.generate(size: [100, 100]) do
        layer SOURCE do
          layer SOURCE
        end
      end
    end
  end

  # libvips' thumbnail applies the EXIF orientation tag; reading the header does
  # not. Measuring one and rendering the other left layout holding a frame the
  # image did not fill.
  def test_layout_and_render_agree_on_an_exif_rotated_source
    rotated = 'test/assets/exif_rotated.jpg' # 200x100 of pixels, upright 100x200
    loader = Loomy::Render::SourceLoader.new

    assert_equal [100, 200], loader.dimensions(rotated)

    canvas = Loomy::DSL::PipelineBuilder.new({}) { layer rotated, width: 50 }.build
    frames, = Loomy::Layout::Engine.new(loader).call(canvas)
    frame = frames.values.first
    image = Loomy.generate { layer rotated, width: 50 }

    assert_equal [frame.width, frame.height], [image.width, image.height]
    assert_equal [50, 100], [image.width, image.height]
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

    def load(path, target = Loomy::Render::Target.natural)
      @requested_sizes << [target.width, target.height]
      @loader.load(path, target)
    end

    def load_trimmed(path, target = Loomy::Render::Target.natural)
      @requested_sizes << [target.width, target.height]
      @loader.load_trimmed(path, target)
    end

    def dimensions(path) = @loader.dimensions(path)
    def trim_bounds(path) = @loader.trim_bounds(path)
  end
end
