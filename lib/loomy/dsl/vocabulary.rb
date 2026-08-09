# frozen_string_literal: true

module Loomy
  module DSL
    # Properties whose value has to come from a known set.
    #
    # The DSL already rejects an unknown property *name*; this rejects an
    # unknown *value* for a name it knows, so `align: :top` fails rather than
    # being quietly ignored.
    #
    # Two shapes of set, because not every one is a list: VALUES holds the
    # closed lists, VALIDATORS the properties that accept a union no list can
    # spell (`width: 20`, `width: '50%'`, `width: :fill`).
    #
    # `blend:` has no list here either, but it is still checked: libvips is
    # *asked* rather than copied. A copy would drift away from whichever libvips
    # is installed, and leaving it unchecked was worse -- the render wraps what
    # libvips raises, so an invalid mode arrived as "libvips failed" when it is
    # the declaration that is wrong. `relight`'s `type:` is the opposite case:
    # Loomy owns that vocabulary and maps it onto a blend mode, so nothing
    # downstream can name the valid values.
    module Vocabulary
      # Each axis names the same three positions differently, and the two
      # vocabularies do not mix.
      ALIGN  = Layout::Placement::HORIZONTAL.keys.freeze
      VALIGN = Layout::Placement::VERTICAL.keys.freeze

      FIT = %i[contain cover stretch].freeze

      VALUES = {
        align: ALIGN,
        valign: VALIGN,
        fit: FIT,
        trim: [true, false, *Render::Trimmer::MODES],
        distribute: AST::Stack::DISTRIBUTIONS,
        direction: AST::Stack::DIRECTIONS
      }.freeze

      GRADIENT_DIRECTIONS = Render::Sources::Gradient::DIRECTIONS
      LIGHTING_TYPES = AST::Effects::Lighting::TYPES

      # A property whose accepted values cannot be written as a list. `match?`
      # decides, and `expected` is the sentence InvalidValue prints where it
      # would otherwise print the list.
      Rule = Data.define(:expected, :predicate) do
        def match?(value) = predicate.call(value)
      end

      # A dimension is a union: a pixel count, a share of the parent box, or the
      # whole of it. The percentage pattern is layout's own, so whatever passes
      # here is exactly what the engine can resolve later.
      #
      # Without this, anything else -- `width: :fil`, `width: '50'` -- reaches
      # layout as an *undeclared* size, so the node silently takes the parent
      # box and the mistake looks like it worked.
      DIMENSION = Rule.new(
        expected: 'an Integer of pixels, a percentage String such as "50%", or :fill',
        predicate: lambda { |value|
          value.is_a?(Integer) || value == :fill ||
            (value.is_a?(String) && value.match?(Layout::Engine::PERCENTAGE))
        }
      )

      VALIDATORS = {
        width: DIMENSION,
        height: DIMENSION
      }.freeze

      # Blend modes libvips has already accepted, so it is asked once per mode
      # per process rather than once per declaration.
      PROVEN_BLENDS = Set.new

      # An anchor is a compound like :bottom_right: at most one word from each
      # axis, in either order, and either half may be left out.
      ANCHOR_EXPECTED = [
        "at most one of #{VALIGN.map(&:inspect).join(', ')}",
        "and one of #{ALIGN.map(&:inspect).join(', ')},",
        'joined by an underscore (e.g. :bottom_right, :middle_center, :center)'
      ].join(' ').freeze

      module_function

      def validate!(properties, node_kind = nil)
        properties.each do |name, value|
          validate_membership!(name, value, node_kind)
          validate_rule!(name, value, node_kind)
        end

        validate_anchor!(properties[:anchor], node_kind)
        validate_gradient!(properties[:gradient], node_kind)
        validate_blend!(properties[:blend], node_kind)
      end

      # A closed set: the value has to be one of the listed ones.
      def validate_membership!(name, value, node_kind)
        allowed = VALUES[name]
        return if allowed.nil? || allowed.include?(value)

        raise InvalidValue.new(name, value, allowed, node_kind)
      end

      # A set with no list to check against, so a predicate decides. A name
      # belongs to one shape or the other, never both.
      def validate_rule!(name, value, node_kind)
        rule = VALIDATORS[name]
        return if rule.nil? || rule.match?(value)

        raise InvalidValue.new(name, value, rule.expected, node_kind)
      end

      def validate_anchor!(anchor, node_kind)
        return if anchor.nil?

        words = anchor.to_s.split('_').map(&:to_sym)
        horizontal = words & ALIGN
        vertical = words & VALIGN

        return if (words - horizontal - vertical).empty? && horizontal.size <= 1 && vertical.size <= 1

        raise InvalidValue.new(:anchor, anchor, ANCHOR_EXPECTED, node_kind)
      end

      def validate_gradient!(gradient, node_kind)
        return unless gradient.is_a?(Hash) && gradient.key?(:direction)
        return if GRADIENT_DIRECTIONS.include?(gradient[:direction])

        raise InvalidValue.new(:'gradient[:direction]', gradient[:direction], GRADIENT_DIRECTIONS, node_kind)
      end

      # The one property whose vocabulary belongs to libvips, so libvips decides.
      # A one-pixel composite is the question: ruby-vips converts the mode to the
      # enum before any pixel work, so a wrong one is refused there and a right one
      # costs 0.1ms, once per mode per process.
      #
      # Asked per mode rather than harvesting the whole list from one deliberate
      # failure. Harvesting reads better, but a reworded message would come back as
      # an empty list and reject *every* blend; this way it only degrades the
      # sentence in the error.
      def validate_blend!(blend, node_kind)
        return if blend.nil? || PROVEN_BLENDS.include?(blend)

        probe = Vips::Image.black(1, 1)
        probe.composite2(probe, blend)
        PROVEN_BLENDS << blend
      rescue Vips::Error => e
        raise InvalidValue.new(:blend, blend, blend_expected(e.message), node_kind)
      end

      # libvips lists every mode it would have taken, which is a better answer
      # than a copy of the list kept here. Quoted from its message, so fall back
      # to naming the source of truth if it ever stops saying it.
      def blend_expected(message)
        listed = message.split('should be one of:').last

        return 'a blend mode the installed libvips supports' if listed.nil? || listed == message

        listed.strip.chomp('.')
      end

      # Effects are built straight from DSL::Effects rather than through a
      # builder, so they never reach validate! above; `relight` calls this
      # itself. Without it an unknown type surfaces as a KeyError from inside
      # the processor, half-way through a render.
      def validate_lighting_type!(type)
        return if LIGHTING_TYPES.include?(type)

        raise InvalidValue.new(:type, type, LIGHTING_TYPES, 'relight')
      end
    end
  end
end
