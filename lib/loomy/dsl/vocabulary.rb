# frozen_string_literal: true

module Loomy
  module DSL
    # Properties whose value has to come from a closed set.
    #
    # The DSL already rejects an unknown property *name*; this rejects an
    # unknown *value* for a name it knows, so `align: :top` fails rather than
    # being quietly ignored.
    #
    # `blend:` is deliberately absent. libvips validates its own enum and its
    # error already lists every valid mode, so a copy here would only drift
    # away from whichever libvips is installed. `relight`'s `type:` is the
    # opposite case and is checked here: Loomy owns that vocabulary and maps it
    # onto a blend mode, so nothing downstream can name the valid values.
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
        trim: [true, false],
        distribute: AST::Stack::DISTRIBUTIONS,
        direction: AST::Stack::DIRECTIONS
      }.freeze

      GRADIENT_DIRECTIONS = Render::Sources::Gradient::DIRECTIONS
      LIGHTING_TYPES = AST::Effects::Lighting::TYPES

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
          allowed = VALUES[name]
          next if allowed.nil? || allowed.include?(value)

          raise InvalidValue.new(name, value, allowed, node_kind)
        end

        validate_anchor!(properties[:anchor], node_kind)
        validate_gradient!(properties[:gradient], node_kind)
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
