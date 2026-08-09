# frozen_string_literal: true

# Loaded explicitly from lib/loomy.rb rather than autoloaded: Zeitwerk maps one
# file to one constant, and these all live directly under Loomy so that
# `rescue Loomy::Error` is the single catch-all a caller needs.
module Loomy
  # Base class for every error Loomy raises on its own behalf.
  #
  # Exactly two categories sit under it and every concrete error is in one of
  # them, so a caller that has to route errors -- to an HTTP status, a retry, a
  # bug report -- branches on the category and never on the leaf. A leaf added
  # later then lands in the right place without the caller being taught it.
  class Error < StandardError
    # Machine-readable name for this error, for a caller putting it on a wire.
    # This, not the class name, is the part we keep stable: classes get renamed
    # and a downstream error code should not move when they do. Answers rather
    # than raises -- it runs inside somebody's error handler.
    def code = :unknown

    # Our sentence, with libvips' own message quoted underneath rather than folded
    # in: it names the operation that refused and usually lists what it would have
    # accepted, and it moves between libvips releases -- which is why it is there
    # to be read and never matched on.
    #
    # Dropped when it says nothing: libvips' error buffer is sometimes empty, and
    # Vips::Error then reports its own class name.
    def self.with_vips_detail(summary, detail)
      detail = detail.to_s.strip
      return summary if detail.empty? || detail == 'Vips::Error'

      "#{summary}\nlibvips said: #{detail}"
    end
  end

  # The declaration could not be honoured as written: something the caller asked
  # for is wrong. Rescue it to catch the group; nothing raises it directly.
  class DeclarationError < Error; end

  # The declaration was fine and carrying it out failed. Rescue it to catch the
  # group; nothing raises it directly.
  class ProcessingError < Error; end

  # ---- the declaration is wrong ---------------------------------------------

  # A layer points at a file that does not exist or cannot be read.
  class SourceNotFound < DeclarationError
    attr_reader :path

    def initialize(path)
      @path = path
      super("Image source not found or unreadable: #{path.inspect}")
    end

    def code = :source_not_found
  end

  # A layer points at a file that opens but holds no image libvips can decode:
  # truncated part-way, or not an image at all. Separate from SourceNotFound
  # because they are different answers: nothing to read there, against something
  # to read that is not a usable image.
  class InvalidSource < DeclarationError
    attr_reader :path

    def initialize(path, detail = nil)
      @path = path
      super(Error.with_vips_detail("Cannot decode image source: #{path.inspect}", detail))
    end

    def code = :invalid_source
  end

  # A colour value could not be parsed.
  class InvalidColor < DeclarationError
    attr_reader :value

    def initialize(value)
      @value = value
      super(<<~MESSAGE.strip)
        Cannot parse colour #{value.inspect}. Accepted forms:
          '#rgb', '#rrggbb', '#rrggbbaa'  (the leading # is optional)
          [r, g, b] or [r, g, b, a]       (integers, 0-255)
      MESSAGE
    end

    def code = :invalid_color
  end

  # `use :name` referenced a style that was never defined.
  class UnknownStyle < DeclarationError
    def initialize(name, known = [])
      listed = known.empty? ? '(none defined)' : known.map(&:inspect).join(', ')
      super("Style #{name.inspect} is not defined. Known styles: #{listed}")
    end

    def code = :unknown_style
  end

  # A DSL block called something the current node does not support -- e.g.
  # `solid` inside a `group`, or `layer` inside a leaf layer.
  class UnknownProperty < DeclarationError
    def initialize(name, node_kind, known = [])
      super(<<~MESSAGE.strip)
        Unknown property #{name.to_s.inspect} for #{node_kind}.
        Available here: #{known.sort.join(', ')}
      MESSAGE
    end

    def code = :unknown_property
  end

  # A property was given a value outside its vocabulary -- e.g. `align: :top`,
  # where :top belongs to the vertical axis.
  class InvalidValue < DeclarationError
    attr_reader :property, :value

    # `allowed` is either the list of accepted values or, where the accepted set
    # is not a flat list, a sentence describing it.
    def initialize(property, value, allowed, node_kind = nil)
      @property = property
      @value = value
      where = node_kind ? " on #{node_kind}" : ''
      expected = allowed.is_a?(String) ? allowed : allowed.map(&:inspect).join(', ')

      super(<<~MESSAGE.strip)
        Invalid value for `#{property}`#{where}: #{value.inspect}
        Expected: #{expected}
      MESSAGE
    end

    def code = :invalid_value
  end

  # An effect was declared that nothing knows how to apply. Registration is by
  # exact class, so a subclass of a registered effect lands here too.
  class UnknownEffect < DeclarationError
    attr_reader :effect_class

    def initialize(effect_class, known = [])
      @effect_class = effect_class
      listed = known.empty? ? '(none registered)' : known.map(&:to_s).sort.join(', ')

      super(<<~MESSAGE.strip)
        No processor registered for effect #{effect_class}.
        Register one with Loomy.register_effect, for that exact class.
        Registered: #{listed}
      MESSAGE
    end

    def code = :unknown_effect
  end

  # Geometry could not be resolved -- e.g. a percentage against a box with no
  # resolvable size.
  class LayoutError < DeclarationError
    def code = :layout_error
  end

  # ---- carrying it out failed -----------------------------------------------

  # libvips refused an operation the composition asked for. #cause carries the
  # Vips::Error. One class for all of them, because libvips' own message already
  # names which operation refused and #cause points a backtrace at the call.
  class BackendError < ProcessingError
    def initialize(context, detail = nil)
      super(Error.with_vips_detail("#{context} failed in libvips", detail))
    end

    def code = :backend_error
  end

  # The finished image could not be written: a format libvips has no saver for,
  # a write option it does not have, or a destination it cannot open.
  class EncodeError < ProcessingError
    attr_reader :target

    def initialize(target, detail = nil)
      @target = target
      super(Error.with_vips_detail("Cannot encode to #{target.inspect}", detail))
    end

    def code = :encode_error
  end

  # Loomy reached a state it does not handle. Always a bug in Loomy rather than
  # anything a caller can fix: the message says what fell through, and it is
  # worth reporting.
  class InternalError < ProcessingError
    def code = :internal_error
  end
end
