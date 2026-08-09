# frozen_string_literal: true

module Loomy
  module Render
    module Sources
      # Rendered text, as a coloured image masked by the glyph coverage.
      #
      # Layout uses #mask on its own to measure the text before anything is
      # composited, so the mask is built once and reused.
      class Text
        DEFAULT_FONT = 'sans'
        DEFAULT_SIZE = 24
        DEFAULT_COLOR = '#000'

        def initialize(node, width: nil)
          @node = node
          @width = width
        end

        # Greyscale coverage of the glyphs. `width` wraps the text; 0 means no
        # wrapping, which is what libvips expects.
        def mask
          @mask ||= Vips::Image.text(@node.text.to_s, font: font, width: @width || 0)
        end

        def call
          fill = Sources::Solid.new(color, mask.width, mask.height).call

          fill.extract_band(0, n: 3).bandjoin(mask)
        end

        private

        def font = "#{@node.font || DEFAULT_FONT} #{@node.size || DEFAULT_SIZE}"
        def color = @node.color || DEFAULT_COLOR
      end
    end
  end
end
