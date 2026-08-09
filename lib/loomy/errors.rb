# frozen_string_literal: true

# Loaded explicitly from lib/loomy.rb rather than autoloaded: Zeitwerk maps one
# file to one constant, and these all live directly under Loomy so that
# `rescue Loomy::Error` is the single catch-all a caller needs.
module Loomy
  # Base class for every error Loomy raises on its own behalf.
  class Error < StandardError; end

  # A layer points at a file that does not exist or cannot be read.
  class SourceNotFound < Error
    attr_reader :path

    def initialize(path)
      @path = path
      super("Image source not found or unreadable: #{path.inspect}")
    end
  end

  # A colour value could not be parsed.
  class InvalidColor < Error
    attr_reader :value

    def initialize(value)
      @value = value
      super(<<~MESSAGE.strip)
        Cannot parse colour #{value.inspect}. Accepted forms:
          '#rgb', '#rrggbb', '#rrggbbaa'  (the leading # is optional)
          [r, g, b] or [r, g, b, a]       (integers, 0-255)
      MESSAGE
    end
  end

  # `use :name` referenced a style that was never defined.
  class UnknownStyle < Error
    def initialize(name, known = [])
      listed = known.empty? ? '(none defined)' : known.map(&:inspect).join(', ')
      super("Style #{name.inspect} is not defined. Known styles: #{listed}")
    end
  end

  # A DSL block called something the current node does not support -- e.g.
  # `solid` inside a `group`, or `layer` inside a leaf layer.
  class UnknownProperty < Error
    def initialize(name, node_kind, known = [])
      super(<<~MESSAGE.strip)
        Unknown property #{name.to_s.inspect} for #{node_kind}.
        Available here: #{known.sort.join(', ')}
      MESSAGE
    end
  end

  # Geometry could not be resolved -- e.g. a percentage against a box with no
  # resolvable size.
  class LayoutError < Error; end
end
