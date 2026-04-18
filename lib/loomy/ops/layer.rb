module Loomy
  module Ops
    class Layer
      attr_reader :image, :props
      attr_accessor :op

        def initialize(op, props)
          @op    = op
          @props = props
        end

        def prepare(context)
          @image = ensure_srgb(@op.call(context))
          self
        end

        def resolve(pw, ph)
          img  = apply_fill(@image, pw, ph)
          x, y = calculate_coordinates(img, pw, ph)
          [img, blend, x, y]
        end

        def x     = @props[:x] || 0
        def y     = @props[:y] || 0
        def max_x = x + @image.width
        def max_y = y + @image.height
        def blend = @props[:blend] || :over

        private

        def apply_fill(img, pw, ph)
          return img unless @props[:width] == :fill || @props[:height] == :fill

          tw = @props[:width]  == :fill ? pw : img.width
          th = @props[:height] == :fill ? ph : img.height
          img.thumbnail_image(tw, height: th, size: :both)
        end

        def calculate_coordinates(img, pw, ph)
          return resolve_anchor(img, pw, ph) if @props[:anchor]

          [
            @props[:align]  ? resolve_align(img, pw)  : x,
            @props[:valign] ? resolve_valign(img, ph) : y
          ]
        end

        def resolve_align(img, pw)
          case @props[:align]
          when :center then (pw - img.width) / 2 + @props[:offset_x].to_i
          when :right  then pw - img.width - @props[:offset_x].to_i
          when :left   then @props[:offset_x].to_i
          else x
          end
        end

        def resolve_valign(img, ph)
          case @props[:valign]
          when :middle then (ph - img.height) / 2 + @props[:offset_y].to_i
          when :bottom then ph - img.height - @props[:offset_y].to_i
          when :top    then @props[:offset_y].to_i
          else y
          end
        end

        def resolve_anchor(img, pw, ph)
          anchors = {
            right:  ->(total, iw, off) { total - iw - off },
            center: ->(total, iw, off) { (total - iw) / 2 + off },
            bottom: ->(total, ih, off) { total - ih - off },
            middle: ->(total, ih, off) { (total - ih) / 2 + off }
          }

          str = @props[:anchor].to_s
          ax, ay = str[/right|center/], str[/bottom|middle/]

          res_x = ax ? anchors[ax.to_sym].call(pw, img.width, @props[:offset_x].to_i) : @props[:offset_x].to_i
          res_y = ay ? anchors[ay.to_sym].call(ph, img.height, @props[:offset_y].to_i) : @props[:offset_y].to_i

          [res_x, res_y]
        end

        def ensure_srgb(img)
          img.bands >= 3 && img.interpretation == :multiband ? img.copy(interpretation: :srgb) : img
        end
    end
  end
end
