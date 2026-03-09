module Loomy
  module Ops
    class Pipeline < Base
      class Layer
        attr_reader :image, :x, :y

        def initialize(op, props)
          @op    = op
          @props = props
          @x     = props[:x] || 0
          @y     = props[:y] || 0
        end

        # Loads the image header/graph and returns self for chaining
        def prepare(context)
          @image = ensure_srgb(@op.call(context))
          self
        end

        # Resolves fills and semantic positioning based on parent dimensions
        def resolve(pw, ph)
          apply_fill!(pw, ph)
          calculate_coordinates!(pw, ph)
          [@image, blend, @x, @y]
        end

        def max_x = @x + @image.width
        def max_y = @y + @image.height
        def blend = @props[:blend] || :over

        private

        def apply_fill!(pw, ph)
          return unless @props[:width] == :fill || @props[:height] == :fill

          target_w = @props[:width]  == :fill ? pw : @image.width
          target_h = @props[:height] == :fill ? ph : @image.height
          @image = @image.thumbnail_image(target_w, height: target_h, size: :both)
        end

        def calculate_coordinates!(pw, ph)
          if @props[:anchor]
            @x, @y = resolve_anchor(pw, ph)
          else
            @x = resolve_align(pw)  if @props[:align]
            @y = resolve_valign(ph) if @props[:valign]
          end
        end

        def resolve_align(pw)
          case @props[:align]
          when :center then (pw - @image.width) / 2 + @props[:offset_x]
          when :right  then pw - @image.width - @props[:offset_x]
          when :left   then @props[:offset_x]
          else @x
          end
        end

        def resolve_valign(ph)
          case @props[:valign]
          when :middle then (ph - @image.height) / 2 + @props[:offset_y]
          when :bottom then ph - @image.height - @props[:offset_y]
          when :top    then @props[:offset_y]
          else @y
          end
        end

        def resolve_anchor(pw, ph)
          anchors = {
            right:  ->(total, img, off) { total - img - off },
            center: ->(total, img, off) { (total - img) / 2 + off },
            bottom: ->(total, img, off) { total - img - off },
            middle: ->(total, img, off) { (total - img) / 2 + off }
          }

          str = @props[:anchor].to_s
          ax, ay = str[/right|center/], str[/bottom|middle/]

          x = ax ? anchors[ax.to_sym].call(pw, @image.width, @props[:offset_x]) : @props[:offset_x]
          y = ay ? anchors[ay.to_sym].call(ph, @image.height, @props[:offset_y]) : @props[:offset_y]
          
          [x, y]
        end

        def ensure_srgb(img)
          img.bands >= 3 && img.interpretation == :multiband ? img.copy(interpretation: :srgb) : img
        end
      end
    end
  end
end
