# frozen_string_literal: true

require 'test_helper'

# A text layer is as big as the glyphs pango sets: `width:` is where lines
# break, never a box to scale them into. Layout used to contain the wrapped size
# into the declared width, which the renderer never drew (#34).
class LayoutTextTest < Minitest::Test
  COPY = 'Selected pieces, in the finish you already know, at a price that will not come round again.'

  # width: wraps; it is not a box the glyphs get scaled into. The frame used to
  # be the wrapped size contained into 600 wide, which nothing ever drew.
  def test_text_width_wraps_and_the_frame_is_the_wrapped_size
    frames, = layout(size: [900, 400]) { layer text: COPY, size: 30, width: 600, align: :center }

    assert_frame({ x: (900 - pango(COPY, 30, 600).width) / 2, y: 0, **pango_size(COPY, 30, 600) }, frames.values.first)
  end

  # The worst case for the old contain: one axis declared, so short text was
  # blown up to fill it -- 'Sale' measured 600x226 around 61x23 of ink.
  def test_short_text_in_a_wide_box_keeps_its_natural_size
    frames, = layout(size: [900, 400]) { layer text: 'Sale', size: 30, width: 600 }

    assert_frame({ x: 0, y: 0, **pango_size('Sale', 30, 0) }, frames.values.first)
  end

  def test_text_percentage_width_wraps_at_its_share_of_the_parent
    frames, = layout(size: [900, 400]) { layer text: COPY, size: 30, width: '50%' }

    assert_frame({ x: 0, y: 0, **pango_size(COPY, 30, 450) }, frames.values.first)
  end

  def test_text_fill_width_wraps_at_the_parent_width
    frames, = layout(size: [900, 400]) { layer text: COPY, size: 30, width: :fill }

    assert_frame({ x: 0, y: 0, **pango_size(COPY, 30, 900) }, frames.values.first)
  end

  def test_text_without_width_is_its_natural_size
    frames, = layout(size: [900, 400]) { layer text: COPY, size: 30 }

    assert_frame({ x: 0, y: 0, **pango_size(COPY, 30, 0) }, frames.values.first)
  end

  # The renderer draws what layout measured, not a copy it builds itself.
  def test_layout_hands_the_renderer_the_text_it_measured
    frames, _size, texts = layout(size: [900, 400]) { layer text: COPY, size: 30, width: '50%' }

    node, frame = frames.first

    assert_equal [frame.width, frame.height], [texts.fetch(node).mask.width, texts.fetch(node).mask.height]
  end

  def test_text_refuses_a_height
    error = assert_raises(Loomy::LayoutError) { layout(size: [900, 400]) { layer text: COPY, width: 600, height: 50 } }

    assert_match(/width: sets where they break/, error.message)
  end

  def test_text_refuses_the_fits_that_would_scale_it
    %i[cover stretch].each do |fit|
      assert_raises(Loomy::LayoutError) { layout(size: [900, 400]) { layer text: COPY, width: 600, fit: fit } }
    end
  end

  def test_text_accepts_contain_because_it_is_the_default
    default, = layout(size: [900, 400]) { layer text: COPY, width: 600 }
    explicit, = layout(size: [900, 400]) { layer text: COPY, width: 600, fit: :contain }

    assert_equal frame_values(default), frame_values(explicit)
  end

  private

  def pango(text, size, width)
    Vips::Image.text(text, font: "#{Loomy::Render::Sources::Text::DEFAULT_FONT} #{size}", width: width)
  end

  def pango_size(text, size, width)
    image = pango(text, size, width)

    { width: image.width, height: image.height }
  end

  def layout(**options, &)
    sources = Loomy::Render::SourceCache.new
    canvas = Loomy::DSL::PipelineBuilder.new(sources, options, &).build
    canvas = Loomy::AST::Pruner.new(canvas).call

    Loomy::Layout::Engine.new(sources).call(canvas)
  end

  def frame_values(frames)
    frames.values.map { |frame| [frame.x, frame.y, frame.width, frame.height] }
  end

  def assert_frame(expected, frame)
    assert_equal expected, { x: frame.x, y: frame.y, width: frame.width, height: frame.height }
  end
end
