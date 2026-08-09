# frozen_string_literal: true

module Loomy
  module Render
    # Walks the tree and produces the image, using the sizes and positions
    # layout already settled on.
    #
    # There is deliberately no intermediate operation graph: libvips is itself a
    # demand-driven pipeline, so building a second one buys nothing. Batched
    # compositing lives in Compositor, source caching in SourceLoader.
    class Renderer < AST::Visitor
      MM_PER_INCH = 25.4

      def initialize(frames:, canvas_size:, loader:, effects:)
        super()
        @frames = frames
        @canvas_size = canvas_size
        @loader = loader
        @effects = effects
      end

      def call(canvas)
        image = visit(canvas)
        with_dpi(image, canvas.dpi)
      end

      def visit_canvas(node)
        composite(node, *@canvas_size)
      end

      def visit_group(node)
        frame = @frames.fetch(node)

        @effects.apply(composite(node, frame.width, frame.height), node.effects)
      end
      alias visit_stack visit_group

      def visit_layer(node)
        frame = @frames.fetch(node)

        @effects.apply(source_image(node, frame), node.effects)
      end

      private

      def composite(node, width, height)
        placed = node.children.map do |child|
          frame = @frames.fetch(child)

          Compositor::Placed.new(image: srgb(visit(child)), blend: child.blend_mode, x: frame.x, y: frame.y)
        end

        Compositor.render(placed, width, height)
      end

      def source_image(node, frame)
        case node.source_type
        when :file then file_image(node, frame)
        when :solid then Sources::Solid.new(node.solid, frame.width, frame.height).call
        when :gradient then Sources::Gradient.new(node.gradient, frame.width, frame.height).call
        when :text then Sources::Text.new(node, width: text_wrap_width(node)).call
        else raise LayoutError, "Layer has no renderable source: #{node.properties.inspect}"
        end
      end

      def file_image(node, frame)
        target = Target.new(width: frame.width, height: frame.height, fit: load_fit(node))

        node.trim ? @loader.load_trimmed(node.source, target, node.trim) : @loader.load(node.source, target)
      end

      # Layout committed to frame.width x frame.height, so the loader has to hit
      # it exactly whenever the declaration asked for a specific box. Two
      # unrelated declarations ask for one: `fit: :stretch`, and `width:`/
      # `height: :fill`, which names the parent's box without saying how to
      # reach it. Under :contain the frame is *derived* from the aspect ratio,
      # so containing into it reproduces it.
      #
      # The order matters: `fit: :cover` wins over a filled axis, because
      # cropping is what was asked for.
      def load_fit(node)
        return :cover if node.fit == :cover
        return :stretch if node.fit == :stretch || node.width == :fill || node.height == :fill

        :contain
      end

      def text_wrap_width(node)
        node.width.is_a?(Numeric) ? node.width : nil
      end

      # libvips composite wants a colour interpretation it can reason about;
      # generated multi-band images arrive without one.
      def srgb(image)
        image.bands >= 3 && image.interpretation == :multiband ? image.copy(interpretation: :srgb) : image
      end

      # libvips stores resolution in pixels per millimetre.
      def with_dpi(image, dpi)
        return image unless dpi

        image.copy(xres: dpi.to_f / MM_PER_INCH, yres: dpi.to_f / MM_PER_INCH)
      end
    end
  end
end
