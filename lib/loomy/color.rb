# frozen_string_literal: true

module Loomy
  class Color
    def initialize(value)
      @value = value
    end

    def rgba
      @rgba ||=
        case @value
        when String then hex_to_rgba(@value)
        when Array  then from_array(@value)
        else [0, 0, 0, 255]
        end
    end

    def r = rgba[0]
    def g = rgba[1]
    def b = rgba[2]
    def a = rgba[3]

    def to_rgb = rgba[0..2]

    private

    def from_array(array) = array.length == 3 ? array + [255] : array

    def hex_to_rgba(hex)
      hex = hex.delete('#')
      parts =
        case hex.length
        when 3 then hex.chars.map { |c| c * 2 }
        when 6, 8 then hex.scan(/../)
        else return [0, 0, 0, 255]
        end

      res = parts.map(&:hex)
      res << 255 if res.length == 3
      res
    end
  end
end
