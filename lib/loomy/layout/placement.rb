# frozen_string_literal: true

module Loomy
  module Layout
    # Turns a node's declared placement into a coordinate inside its parent box.
    #
    # This is the whole of Loomy's positioning vocabulary, in one place.
    module Placement
      # The two axes name the same three positions differently. Keeping the
      # vocabularies separate is deliberate: `align: :top` stays meaningless
      # rather than quietly working.
      HORIZONTAL = { left: :near, center: :centre, right: :far }.freeze
      VERTICAL   = { top: :near, middle: :centre, bottom: :far }.freeze

      # `anchor:` is a compound like :bottom_right or :middle_center. The two
      # halves are independent and either may be absent.
      HORIZONTAL_ANCHOR = /right|center/
      VERTICAL_ANCHOR   = /bottom|middle/

      module_function

      # [x, y] for a node of `size` placed inside `box`.
      #
      # `align_override` supplies the cross-axis alignment a stack imposes on
      # its children, which the child can still override by declaring its own.
      def resolve(node, size, box, align_override: nil, valign_override: nil)
        return anchored(node, size, box) if node.anchor

        align  = node.align || align_override
        valign = node.valign || valign_override

        [
          align ? horizontal(align, size[0], box[0], node.offset_x) || node.x : node.x,
          valign ? vertical(valign, size[1], box[1], node.offset_y) || node.y : node.y
        ]
      end

      def horizontal(align, width, box_width, offset)
        along(HORIZONTAL[align], width, box_width, offset)
      end

      def vertical(valign, height, box_height, offset)
        along(VERTICAL[valign], height, box_height, offset)
      end

      # The arithmetic both axes share. nil for an unrecognised placement, which
      # leaves the caller on the node's declared coordinate.
      def along(placement, length, box_length, offset)
        case placement
        when :near   then offset
        when :centre then ((box_length - length) / 2) + offset
        when :far    then box_length - length - offset
        end
      end

      def anchored(node, size, box)
        anchor = node.anchor.to_s

        [
          horizontal(anchor[HORIZONTAL_ANCHOR]&.to_sym, size[0], box[0], node.offset_x) || node.offset_x,
          vertical(anchor[VERTICAL_ANCHOR]&.to_sym, size[1], box[1], node.offset_y) || node.offset_y
        ]
      end
    end
  end
end
