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

      def initialize(frames:, canvas_size:, loader:, effects:, premultiplied: false)
        super()
        @frames = frames
        @canvas_size = canvas_size
        @loader = loader
        @effects = effects
        @premultiplied = premultiplied
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

      # `premultiplied` applies to every composite, nested ones included, not
      # only the canvas'. Under it a group's composited result genuinely is
      # premultiplied, so the parent claiming so of its child is the only
      # self-consistent reading -- and a canvas-only flag is measurably inert
      # anyway, since the single `over` of a group onto the canvas gives the
      # same pixels either way.
      #
      # It does leave one honest consequence: effects run between a nested
      # composite and its parent, and on_colour_bands splits alpha off assuming
      # straight colour, so adjust_color and relight on a group operate on
      # premultiplied colour. That follows from the option existing at all.
      def composite(node, width, height)
        placed = node.children.map do |child|
          frame = @frames.fetch(child)
          image = srgb(fade(visit(child), child.opacity))

          Compositor::Placed.new(image: image, blend: child.blend_mode, x: frame.x, y: frame.y)
        end

        Compositor.render(placed, width, height, premultiplied: @premultiplied)
      end

      # Scales a node's alpha where it meets its parent, which is what makes one
      # apply site cover layers, groups and stacks alike -- and what puts a
      # node's own effects, which run inside it, always before the fade.
      #
      # Only the alpha band. Scaling all four with a gain of 1 on the colours
      # gives identical pixels and spends its time multiplying three bands by
      # one: 0.92s against 0.63s of CPU over eight 4200x4800 RGBA sources.
      #
      # The cast is not optional: `*` promotes uchar to float, one float child
      # makes every composite above it float, and each golden rendered from a
      # file source then moves by up to 1/255 at 4x the memory.
      #
      # has_alpha? is load-bearing rather than defensive -- SourceLoader adds an
      # alpha band only where it does not resize. And alpha alone stays right
      # under `premultiplied`, where scaling all four would be the consistent
      # thing: the layers are straight-alpha whatever the canvas claims.
      def fade(image, opacity)
        return image if opacity == 1

        image = image.bandjoin(255) unless image.has_alpha?
        alpha = image.extract_band(image.bands - 1)

        image.extract_band(0, n: image.bands - 1).bandjoin((alpha * opacity).cast(alpha.format))
      end

      def source_image(node, frame)
        case node.source_type
        when :file then file_image(node, frame)
        when :solid then Sources::Solid.new(node.solid, frame.width, frame.height).call
        when :gradient then Sources::Gradient.new(node.gradient, frame.width, frame.height).call
        when :text then Sources::Text.new(node, width: text_wrap_width(node)).call
        else raise InternalError, "Layer has no renderable source: #{node.properties.inspect}"
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
