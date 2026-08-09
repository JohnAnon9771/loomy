# frozen_string_literal: true

require 'test_helper'

# Properties that are easy to lose again, each one pinned.
class RegressionTest < Minitest::Test
  SOURCE = 'test/assets/blue_square.png'
  LARGE = 'test/assets/base_large.png' # 4200x4800

  # Rendering reads the tree; it must never write to it.
  def test_rendering_does_not_mutate_the_tree
    canvas = build_canvas(size: [300, 300]) do
      vstack spacing: 10, align: :center do
        layer SOURCE, width: 50, height: 50
        layer SOURCE, width: 50, height: 50
      end
    end

    before = snapshot(canvas)
    2.times { render(canvas) }

    assert_equal before, snapshot(canvas)
  end

  def test_the_same_tree_renders_identically_twice
    canvas = build_canvas(size: [200, 200]) do
      vstack spacing: 5 do
        layer SOURCE, width: 40, height: 40
        layer SOURCE, width: 40, height: 40
      end
    end

    first = render(canvas).write_to_memory
    second = render(canvas).write_to_memory

    assert_equal first, second
  end

  # A layer nested in a group must still be loaded at its target size.
  def test_nested_layers_are_loaded_at_their_final_size
    sources = Loomy::Render::SourceCache.new
    loader = RecordingLoader.new(Loomy::Render::SourceLoader.new(sources))

    canvas = Loomy::DSL::PipelineBuilder.new(sources, { size: [1000, 1000] }) do
      group x: 100, y: 100, width: 400, height: 400 do
        layer LARGE, width: 200, height: 200
      end
    end.build

    frames, size = Loomy::Layout::Engine.new(sources).call(canvas)
    Loomy::Render::Renderer.new(
      frames: frames, canvas_size: size, loader: loader,
      effects: Loomy::Render::EffectRegistry.snapshot(loader)
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
    assert_kind_of Class, Loomy::Render::SourceCache
    assert_kind_of Class, Loomy::Render::AccessPlan
  end

  # Streaming a source is a single downward pass. Every one of these reads a
  # source twice, and each failed with `vipspng: out of order read` while the
  # renderer streamed by default rather than on proof it was safe to.
  def test_a_trimmed_source_survives_the_render_path
    Loomy.to_blob('.png', size: [200, 200]) do
      layer 'test/assets/trim_test_source.png', trim: true
    end
  end

  def test_the_same_source_behind_two_layers_survives_the_render_path
    Loomy.to_blob('.png', size: [200, 200]) do
      layer SOURCE
      layer SOURCE, x: 10
    end
  end

  # Loomy.generate hands back a lazy image; the caller decides how often to read
  # it, so nothing it depends on may be a one-shot read.
  def test_a_generated_image_can_be_read_more_than_once
    image = Loomy.generate(size: [100, 100]) { layer SOURCE }

    image.avg

    assert_equal [100, 100], [image.width, image.height]
    refute_empty image.write_to_memory
  end

  # bounds_of opens the source during DSL evaluation, before there is a pruned
  # tree to plan against. Its scan plus the render's read is two passes.
  def test_a_source_measured_by_bounds_of_survives_being_rendered
    source = 'test/assets/trim_test_source.png'

    Loomy.to_blob('.png', size: [200, 200]) do
      bounds_of source
      layer source
    end
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
    sources = Loomy::Render::SourceCache.new

    assert_equal [100, 200], sources.dimensions(rotated)

    canvas = Loomy::DSL::PipelineBuilder.new(sources, {}) { layer rotated, width: 50 }.build
    frames, = Loomy::Layout::Engine.new(sources).call(canvas)
    frame = frames.values.first
    image = Loomy.generate { layer rotated, width: 50 }

    assert_equal [frame.width, frame.height], [image.width, image.height]
    assert_equal [50, 100], [image.width, image.height]
  end

  # bounds_of used to open the file itself, so it reported the frame the file is
  # stored in while everything else measured the upright one: 200x100 against
  # 100x200. Positioning against it landed in a coordinate space that was never
  # rendered.
  def test_bounds_of_agrees_with_the_rendered_frame_on_an_exif_rotated_source
    rotated = 'test/assets/exif_rotated.jpg' # 200x100 of pixels, upright 100x200
    bounds = nil

    image = Loomy.generate do
      bounds = bounds_of rotated
      layer rotated
    end

    assert_equal [100, 200], [bounds.width, bounds.height]
    assert_equal [image.width, image.height], [bounds.width, bounds.height]
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

  def build_canvas(**options, &)
    Loomy::DSL::PipelineBuilder.new(Loomy::Render::SourceCache.new, options, &).build
  end

  # A fresh cache per render: sharing one would serve the second render out of
  # the first one's measurements, and the assertions here are about what the
  # pipeline recomputes.
  def render(canvas)
    Loomy::Render::Pipeline.new(canvas, Loomy::Render::SourceCache.new).call
  end

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

    def load_trimmed(path, target = Loomy::Render::Target.natural, mode = :auto)
      @requested_sizes << [target.width, target.height]
      @loader.load_trimmed(path, target, mode)
    end

    def load_map(path, target) = @loader.load_map(path, target)
  end
end
