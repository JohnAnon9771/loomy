# frozen_string_literal: true

module Loomy
  # Parses the colour values accepted by the DSL into an RGBA byte quadruple.
  #
  #   Color.new('#f00').rgba        #=> [255, 0, 0, 255]
  #   Color.new('#0000ff80').rgba   #=> [0, 0, 255, 128]
  #   Color.new([10, 20, 30]).rgba  #=> [10, 20, 30, 255]
  #
  # Anything it cannot parse raises InvalidColor. It used to return opaque
  # black instead, which meant a typo in a hex string rendered silently.
  class Color
    HEX = /\A(\h{3}|\h{6}|\h{8})\z/
    CHANNEL_RANGE = (0..255)
    OPAQUE = 255

    def initialize(value)
      @value = value
    end

    def rgba
      @rgba ||=
        case @value
        when Color  then @value.rgba
        when String then from_hex(@value)
        when Array  then from_array(@value)
        else raise InvalidColor, @value
        end
    end

    def r = rgba[0]
    def g = rgba[1]
    def b = rgba[2]
    def a = rgba[3]

    def to_rgb = rgba[0..2]

    private

    def from_array(array)
      unless [3, 4].include?(array.length) &&
             array.all? { |c| c.is_a?(Numeric) && CHANNEL_RANGE.cover?(c) }
        raise InvalidColor, @value
      end

      channels = array.map(&:to_i)
      channels.length == 3 ? channels + [OPAQUE] : channels
    end

    def from_hex(value)
      hex = value.delete_prefix('#')
      raise InvalidColor, @value unless HEX.match?(hex)

      hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3

      channels = hex.scan(/../).map(&:hex)
      channels.length == 3 ? channels + [OPAQUE] : channels
    end
  end
end
