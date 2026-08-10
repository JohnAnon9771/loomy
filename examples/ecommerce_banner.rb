#!/usr/bin/env ruby
# frozen_string_literal: true

# A ready-to-run ecommerce hero banner, composed entirely with Loomy.
#
#   bundle exec ruby examples/ecommerce_banner.rb
#   bundle exec ruby examples/ecommerce_banner.rb --theme ivory --preset square
#   bundle exec ruby examples/ecommerce_banner.rb --product shoe.png --out hero.jpg
#   bundle exec ruby examples/ecommerce_banner.rb --all --out banners
#
# Every soft edge here comes from a Loomy primitive, because Loomy has no
# rounded corners or masking yet (see the roadmap) and no radial gradient:
#
#   light      a two-stop gradient whose far stop is the same colour at alpha 0
#   glow       a solid inset inside a *larger* group, then blurred -- the blur
#              feathers into the group's transparent margin, which is the only
#              way to get a soft edge out of `blur` (on a full-bleed solid it
#              has nothing to bleed into and the rectangle stays hard)
#   shadow     the same trick in the theme's shade colour, under the artwork
#
# Type is measured with `Vips::Image.text` before the render, for three reasons:
#
#   - No text layer here declares a `width:`. One that does gets wrapped by
#     pango at that width, but layout then sizes its *frame* as if the glyphs
#     had been scaled to fill it, and the renderer never scales them -- so the
#     frame is wider than the ink and anything aligned against it sits off
#     centre by half the difference. Wrapping is settled here instead.
#   - A button has to be as wide as its label plus padding, and nothing but a
#     measurement knows how wide the words are.
#   - The headline steps down until the column fits its box, which means
#     measuring the column before anything is drawn.

require 'optparse'
require 'vips'
require_relative '../lib/loomy'

module EcommerceBanner
  # Canvas sizes worth having on hand, each with the type scale that keeps the
  # column reading the same at that size. `layout` picks which of the two
  # arrangements below the canvas is cut into.
  Preset = Data.define(:size, :layout, :scale)

  PRESETS = {
    'hero' => Preset.new(size: [1600, 600], layout: :split, scale: 1.0),
    'wide' => Preset.new(size: [1920, 720], layout: :split, scale: 1.15),
    'square' => Preset.new(size: [1080, 1080], layout: :stacked, scale: 1.05),
    'story' => Preset.new(size: [1080, 1920], layout: :stacked, scale: 1.2)
  }.freeze

  # A palette. Colours are 6-digit hex so `tint` can append an alpha byte to any
  # of them; `shade` is what the vignette and the drop shadow are made of, kept
  # apart from black because a warm background wants a warm shadow.
  # `vignette` is how far the shade is carried down the canvas. It is declared
  # per palette rather than shared, because the amount that grounds a dark
  # background muddies a light one.
  Theme = Data.define(
    :bg_from, :bg_to, :glow, :halo, :accent, :accent_hi, :on_accent, :ink, :muted, :shade, :vignette
  )

  THEMES = {
    'midnight' => Theme.new(
      bg_from: '#0a0f24', bg_to: '#1b1f4d', glow: '#3f5efb', halo: '#6c8cff',
      accent: '#ffb703', accent_hi: '#ffd166', on_accent: '#0a0f24',
      ink: '#ffffff', muted: '#c3caea', shade: '#03050f', vignette: 0.5
    ),
    'orchid' => Theme.new(
      bg_from: '#1a0a2b', bg_to: '#45115e', glow: '#c026d3', halo: '#f472b6',
      accent: '#ff5d73', accent_hi: '#ff98a8', on_accent: '#1a0a2b',
      ink: '#ffffff', muted: '#e2ccf0', shade: '#0d0417', vignette: 0.5
    ),
    'verdant' => Theme.new(
      bg_from: '#052a20', bg_to: '#0d4436', glow: '#10b981', halo: '#5eead4',
      accent: '#ffd166', accent_hi: '#ffe6ad', on_accent: '#052a20',
      ink: '#ffffff', muted: '#b7ddd0', shade: '#01120d', vignette: 0.5
    ),
    'ivory' => Theme.new(
      bg_from: '#fdfaf5', bg_to: '#eadfce', glow: '#e2b98d', halo: '#ffffff',
      accent: '#1f3d2b', accent_hi: '#336044', on_accent: '#fdfaf5',
      ink: '#191410', muted: '#6f6459', shade: '#8a6a4a', vignette: 0.26
    )
  }.freeze

  # Family lists, so the script keeps its intended look where these exist and
  # degrades to the platform sans where they do not. Pango reads the whole
  # comma-separated list as the family and the trailing word as the weight.
  SANS = 'Inter, Helvetica Neue, Segoe UI, DejaVu Sans, sans'
  DISPLAY = "#{SANS} Bold".freeze

  # Type sizes at scale 1.0, in points. The headline is a ceiling rather than a
  # promise -- see `fit_column`.
  SIZES = {
    eyebrow: 15, headline: 58, subhead: 20, price: 34, cta: 18,
    badge_value: 42, badge_label: 14, note: 13
  }.freeze

  # The gap that *follows* each block of the text column. Tighter above a line
  # than below it is what gives the column its rhythm, so these are not uniform
  # and a stack -- one `spacing:` for every gap -- would not reproduce them.
  GAPS = { kicker: 18, eyebrow: 24, headline: 20, subhead: 26, price: 30 }.freeze

  # Measuring, wrapping, and the one thing both need: the pango font string.
  module Type
    module_function

    def font(family, size) = "#{family} #{size}"

    # Line breaking asks for the same measurement over and over -- once per
    # candidate line, per wrap, per step of `fit_column` -- and the answer only
    # depends on the two arguments, so it is kept.
    CACHE = {} # rubocop:disable Style/MutableConstant -- filled as it goes

    # Loomy renders text through `Vips::Image.text(..., width: 0)`, so measuring
    # the same call is measuring exactly what will be drawn.
    def measure(content, font)
      CACHE[[content, font]] ||= begin
        image = Vips::Image.text(content.to_s, font: font)

        [image.width, image.height]
      end
    end

    def width_of(content, font) = measure(content, font)[0]
    def height_of(content, font) = measure(content, font)[1]

    # Greedy line breaking against measured widths, returned as one string with
    # newlines: pango lays those out itself, so the whole headline stays a
    # single layer and keeps its natural leading.
    def wrap(content, font, max_width)
      content.to_s.split("\n").flat_map { |paragraph| wrap_paragraph(paragraph, font, max_width) }.join("\n")
    end

    # A word wider than the box still gets its own line rather than being
    # dropped -- overflowing is visible, and disappearing is not.
    def wrap_paragraph(paragraph, font, max_width)
      paragraph.split(/\s+/).each_with_object([]) do |word, lines|
        candidate = lines.empty? ? word : "#{lines.last} #{word}"

        if !lines.empty? && width_of(candidate, font) <= max_width
          lines[-1] = candidate
        else
          lines << word
        end
      end
    end

    # Greedy wrapping at the full column width leaves widows -- one short word
    # alone on the last line -- which is the difference between type that was
    # set and type that merely fitted. Wrapping the same words into the same
    # number of lines inside a *narrower* box has to even them out, so the
    # narrowest box that still breaks into that many lines is the balanced one.
    def balance(content, font, max_width)
      lines = wrap(content, font, max_width).split("\n")
      return lines.join("\n") if lines.size < 2

      best = lines
      width = max_width

      while width > max_width * 0.5
        width = (width * 0.96).round
        candidate = wrap(content, font, width).split("\n")
        break if candidate.size > lines.size

        best = candidate
      end

      best.join("\n")
    end
  end

  # A box on the canvas. Both arrangements below produce one for the copy and
  # one for the artwork, and the composition reads from those rather than from
  # the preset, which is what keeps it from branching per layout.
  Region = Data.define(:x, :y, :width, :height) do
    def right = x + width
    def bottom = y + height
  end

  # The measured copy: what to draw, in which font, and how tall that comes to.
  # Built by `fit_column`, which is what the stacked layouts consult before they
  # know where anything goes.
  Column = Data.define(:copy, :fonts, :blocks, :headline_size, :cta_size) do
    def height = EcommerceBanner.column_height(blocks)

    # {name => y} inside a box of this height. Asked once the box is settled,
    # because the box on the stacked layouts is settled from `height` above.
    def positions(box_height) = EcommerceBanner.column_positions(blocks, box_height)
  end

  module_function

  # `#rrggbb` at a share of full opacity, which is how every soft edge in this
  # file is spelled: a gradient ramps its alpha band too, so a stop at alpha 0
  # is a fade to nothing rather than a fade to black.
  def tint(hex, alpha) = format('%<hex>s%<alpha>02x', hex: hex, alpha: (alpha.clamp(0, 1) * 255).round)

  # The margin the whole composition sits inside, and the width of the column,
  # both of which are settled before anything is measured -- which is what lets
  # the column be measured at all.
  def frame_of(preset)
    width, height = preset.size

    if preset.layout == :split
      pad = [height * 0.11, width * 0.05].max.round
      { pad: pad, text_width: (width * 0.41).round, align: :left }
    else
      pad = (width * 0.09).round
      { pad: pad, text_width: width - (pad * 2), align: :center }
    end
  end

  # How tall the column may grow before `fit_column` starts stepping the
  # headline down. On the split layouts that is the whole content band; on the
  # stacked ones the artwork has to be left something to stand in.
  def column_budget(preset, frame, foot)
    height = preset.size[1]
    content = height - foot - (frame[:pad] * 2)

    preset.layout == :split ? content : content - (frame[:text_width] * 0.45).round
  end

  # Copy beside artwork: the wide banners, where a column at the left and a
  # product at the right is the shape a storefront expects. The two share the
  # content band, so neither depends on the other.
  def split_regions(preset, frame, foot)
    width, height = preset.size
    pad = frame[:pad]
    art_x = (width * 0.53).round
    band = height - foot - (pad * 2)

    {
      text: Region.new(x: pad, y: pad, width: frame[:text_width], height: band),
      art: Region.new(x: art_x, y: pad, width: width - art_x - pad, height: band)
    }
  end

  # Artwork above copy, centred: the square and vertical crops, where a column
  # at one side would leave the other half empty.
  #
  # The column takes exactly the height it needs, sat above the benefits strip,
  # and the artwork takes everything left over -- which is what stops a tall
  # canvas from opening a hole between the two. Left over can be more than the
  # artwork wants, though, so it is capped to a portrait of its own width and
  # what remains is split above and below it.
  def stacked_regions(preset, frame, foot, column)
    height = preset.size[1]
    pad = frame[:pad]
    text_height = column.height
    text_y = height - foot - (height * 0.035).round - text_height
    art_y = pad
    art_height = text_y - (height * 0.06).round - art_y
    ceiling = (frame[:text_width] * 1.15).round

    art_y += (art_height - ceiling) / 2 if art_height > ceiling

    {
      art: Region.new(x: pad, y: art_y, width: frame[:text_width], height: [art_height, ceiling].min),
      text: Region.new(x: pad, y: text_y, width: frame[:text_width], height: text_height)
    }
  end

  def regions_for(preset, frame, foot, column)
    return split_regions(preset, frame, foot) if preset.layout == :split

    stacked_regions(preset, frame, foot, column)
  end

  def fonts_for(scale, headline_size)
    sizes = SIZES.transform_values { |size| (size * scale).round }.merge(headline: headline_size)

    {
      eyebrow: Type.font(DISPLAY, sizes[:eyebrow]), headline: Type.font(DISPLAY, sizes[:headline]),
      subhead: Type.font(SANS, sizes[:subhead]), price: Type.font(DISPLAY, sizes[:price]),
      cta: Type.font(DISPLAY, sizes[:cta]), note: Type.font(SANS, sizes[:note]),
      badge_value: Type.font(DISPLAY, sizes[:badge_value]), badge_label: Type.font(DISPLAY, sizes[:badge_label])
    }
  end

  # The copy, in the order it stacks, as [name, height] pairs. Anything the
  # caller blanked out is dropped here, so the column closes up rather than
  # leaving a hole.
  def column_blocks(copy, fonts, kicker_height, cta_height)
    blocks = [[:kicker, kicker_height]]

    %i[eyebrow headline subhead price].each do |field|
      blocks << [field, Type.height_of(copy[field], fonts[field])] if copy[field]
    end
    blocks << [:cta, cta_height] if copy[:cta]

    blocks
  end

  def column_height(blocks)
    blocks.sum { |_name, height| height } + blocks[0..-2].sum { |name, _height| GAPS.fetch(name, 0) }
  end

  # {name => y}, relative to the text region, with the column centred in it as a
  # whole rather than each block placed from the top.
  def column_positions(blocks, region_height)
    cursor = [(region_height - column_height(blocks)) / 2, 0].max

    blocks.each_with_object({}) do |(name, height), positions|
      positions[name] = cursor
      cursor += height + GAPS.fetch(name, 0)
    end
  end

  # The declared type sizes are a starting point, not a promise: the copy
  # belongs to the caller and the canvas does not stretch, so the headline steps
  # down until the column fits its box. Wrapping changes with the size, so every
  # step re-wraps -- a dozen `Vips::Image.text` calls at worst, and none of them
  # decodes a pixel of the render.
  def fit_column(copy, width, budget, scale, kicker_height, cta_height)
    ceiling = (SIZES[:headline] * scale).round
    floor = (ceiling * 0.6).round
    step = [(ceiling * 0.05).round, 1].max
    size = ceiling

    loop do
      fonts = fonts_for(scale, size)
      wrapped = wrap_copy(copy, fonts, width)
      blocks = column_blocks(wrapped, fonts, kicker_height, cta_height)

      if column_height(blocks) <= budget || size <= floor
        return Column.new(copy: wrapped, fonts: fonts, blocks: blocks,
                          headline_size: size, cta_size: (SIZES[:cta] * scale).round)
      end

      size -= step
    end
  end

  # A line of body copy stops being comfortable to read somewhere past sixty
  # characters, and the stacked layouts give the column the whole canvas to run
  # across. So the subhead breaks at the narrower of the column and its own
  # measure, while the headline -- one glance, not a paragraph -- takes the
  # column.
  MEASURE = 62

  def wrap_copy(copy, fonts, width)
    subhead_width = [width, Type.width_of('n' * MEASURE, fonts[:subhead])].min

    copy.merge(
      headline: copy[:headline] && Type.balance(copy[:headline], fonts[:headline], width),
      subhead: copy[:subhead] && Type.balance(copy[:subhead], fonts[:subhead], subhead_width)
    )
  end

  # Decorative artwork for a banner with no product photo: panels standing on a
  # common baseline, each a gradient of one hue fading out upwards, so they
  # dissolve into the light instead of ending on a hard edge, and each capped by
  # a hairline that gives the fade somewhere definite to start. Widths and
  # heights are in twelfths of the region, which is what carries the arrangement
  # across presets of different shapes.
  def collage_panels(region, theme)
    unit = region.width / 12.0
    cap = [(region.height * 0.008).round, 2].max

    # The two flanking panels fade out into a background of their own hue, which
    # is clean. The centre one does not: fading gold over a blue field passes
    # through the mud between them, so it stays opaque and does its shading in
    # two tones of the accent instead.
    [
      { x: 0.0, width: 3.1, height: 0.88, from: tint(theme.halo, 0.04), to: tint(theme.halo, 0.5) },
      { x: 3.7, width: 4.4, height: 1.0, from: theme.accent_hi, to: theme.accent },
      { x: 8.6, width: 3.4, height: 0.62, from: tint(theme.glow, 0.04), to: tint(theme.glow, 0.7) }
    ].map do |panel|
      height = (region.height * panel[:height]).round

      panel.merge(x: (unit * panel[:x]).round, y: region.height - height,
                  width: (unit * panel[:width]).round, height: height, cap: cap)
    end
  end

  # Where the artwork actually lands inside the box it was given. A product is
  # scaled to fit and centred, so it touches at most one pair of the region's
  # edges and can sit far inside the other pair -- and a badge pinned to the
  # region rather than to that box is a badge parked near the product instead of
  # applied to it. The panel composition fills its region by construction, so
  # there it is the region.
  #
  # `bounds` is what `bounds_of` measured, which is the same trim the layer's
  # own `trim: true` will crop to.
  def placed_box(region, bounds)
    return region if bounds.nil?

    factor = [region.width.fdiv(bounds.width), region.height.fdiv(bounds.height)].min
    width = (bounds.width * factor).round
    height = (bounds.height * factor).round

    Region.new(x: region.x + ((region.width - width) / 2), y: region.y + ((region.height - height) / 2),
               width: width, height: height)
  end

  # The same box grown on every side. Used for the halo, whose group has to be
  # the artwork plus the room its blur needs to fade out in -- grown from the
  # artwork rather than declared on the region, so a narrow product gets a glow
  # around itself instead of a lit rectangle behind it.
  def grown(box, margin)
    Region.new(x: box.x - margin, y: box.y - margin,
               width: box.width + (margin * 2), height: box.height + (margin * 2))
  end

  # Only formats that take a quality setting get one; PNG would refuse the
  # option and the render would fail on the write rather than on the geometry.
  def write_options(path)
    File.extname(path).downcase.match?(/\A\.(jpe?g|webp)\z/) ? { quality: 92 } : {}
  end

  def render(output_path, preset:, theme:, copy:, product: nil)
    width, height = preset.size
    scale = preset.scale
    px = ->(value) { (value * scale).round }

    foot_height = copy[:note] ? px[58] : 0
    frame = frame_of(preset)
    align = frame[:align]

    # The button is sized from its label, since nothing else knows how wide the
    # words are. Horizontal padding is the looser of the two, as always.
    cta_width, cta_label_height = copy[:cta] ? Type.measure(copy[:cta], Type.font(DISPLAY, px[SIZES[:cta]])) : [0, 0]
    cta_box_width = cta_width + (px[36] * 2)
    cta_box_height = cta_label_height + (px[20] * 2)

    type_size = SIZES.transform_values { |size| px[size] }
    rule_height = [px[3], 2].max
    rule_width = px[54]

    # Measured before the boxes are cut, because on the stacked layouts the
    # boxes are cut from the answer.
    column = fit_column(copy, frame[:text_width], column_budget(preset, frame, foot_height),
                        scale, rule_height, cta_box_height)
    regions = regions_for(preset, frame, foot_height, column)
    text_region = regions[:text]
    art = regions[:art]
    pos = column.positions(text_region.height)
    text = column.copy

    # Soft-edge geometry. A blur only feathers where it has transparent margin
    # to feather into, so every radius here comes with the margin that lets it,
    # and both are in canvas units so they survive a change of preset.
    halo_blur = px[64]
    halo_margin = (halo_blur * 1.3).round
    shadow_blur = px[22]

    badge_size = px[112]
    panels = product ? [] : collage_panels(art, theme)

    Loomy.render(output_path, size: [width, height], **write_options(output_path)) do
      # Measured through the same cache the render will load the product from,
      # so the box below agrees with what `trim: true` crops to further down.
      # Both the shadow and the badge hang off it.
      drawn = EcommerceBanner.placed_box(art, product && bounds_of(product))
      badge_x = drawn.x - (badge_size / 3)
      badge_y = drawn.y - (badge_size / 6)

      # 1. The ground: a vertical wash, so nothing above it ever meets a flat
      #    field of one colour.
      layer gradient: { from: theme.bg_from, to: theme.bg_to, direction: :top_bottom }

      # 2. A light source on the artwork's side. Left to right on the split
      #    layouts, top down on the stacked ones -- in both cases it brightens
      #    the half the product sits in.
      if preset.layout == :split
        layer gradient: { from: EcommerceBanner.tint(theme.glow, 0),
                          to: EcommerceBanner.tint(theme.glow, 0.4), direction: :left_right }
      else
        layer gradient: { from: EcommerceBanner.tint(theme.glow, 0.36),
                          to: EcommerceBanner.tint(theme.glow, 0), direction: :top_bottom }
      end

      # 3. A vignette in the theme's own shade, which is what stops the copy
      #    from floating on a bright field at the foot of the canvas.
      layer gradient: { from: EcommerceBanner.tint(theme.shade, 0),
                        to: EcommerceBanner.tint(theme.shade, theme.vignette), direction: :top_bottom }

      # 4. The halo: the artwork's own box, grown by the margin its blur needs,
      #    with a solid the size of the artwork sat in the middle of it.
      halo = EcommerceBanner.grown(drawn, halo_margin)

      group x: halo.x, y: halo.y, width: halo.width, height: halo.height, opacity: 0.4 do
        layer solid: theme.halo, align: :center, valign: :middle,
              width: drawn.width, height: drawn.height
        blur radius: halo_blur
      end

      # 5. The shadow the artwork stands on: a slab straddling its foot, grown
      #    the same way so the blur clears every side -- a group only as wide as
      #    the slab would cut the fade off and give the shadow hard flanks.
      #    Kept shallow, so that on the stacked layouts it dies out inside the
      #    gap above the copy rather than in the copy.
      shadow_height = [(drawn.height * 0.09).round, shadow_blur].max
      shadow_width = (drawn.width * 0.8).round
      shadow = EcommerceBanner.grown(
        Region.new(x: drawn.x + ((drawn.width - shadow_width) / 2), y: drawn.bottom - (shadow_height / 2),
                   width: shadow_width, height: shadow_height),
        (shadow_blur * 1.3).round
      )

      group x: shadow.x, y: shadow.y, width: shadow.width, height: shadow.height, opacity: 0.45 do
        layer solid: theme.shade, align: :center, valign: :middle,
              width: shadow_width, height: shadow_height
        blur radius: shadow_blur
      end

      # 6. The artwork itself: the product photo, trimmed to its content so a
      #    transparent or white border does not push it off centre -- or, with
      #    no photo to show, the panel composition.
      group x: art.x, y: art.y, width: art.width, height: art.height do
        if product
          layer product, width: art.width, height: art.height, fit: :contain,
                         align: :center, valign: :middle, trim: true
        else
          panels.each do |panel|
            layer gradient: { from: panel[:from], to: panel[:to], direction: :top_bottom },
                  x: panel[:x], y: panel[:y], width: panel[:width], height: panel[:height]
            layer solid: theme.ink, x: panel[:x], y: panel[:y],
                  width: panel[:width], height: panel[:cap], opacity: 0.45
          end
        end
      end

      # 7. The copy. Drawn inside a group on the text region so `align:` centres
      #    against the column rather than the canvas, which is the whole of the
      #    difference between the two layouts.
      group x: text_region.x, y: text_region.y, width: text_region.width, height: text_region.height do
        layer solid: theme.accent, width: rule_width, height: rule_height, y: pos[:kicker], align: align

        if pos[:eyebrow]
          layer text: text[:eyebrow], font: DISPLAY, size: type_size[:eyebrow],
                color: theme.accent, y: pos[:eyebrow], align: align
        end

        if pos[:headline]
          layer text: text[:headline], font: DISPLAY, size: column.headline_size,
                color: theme.ink, y: pos[:headline], align: align
        end

        if pos[:subhead]
          layer text: text[:subhead], font: SANS, size: type_size[:subhead],
                color: theme.muted, y: pos[:subhead], align: align
        end

        if pos[:price]
          layer text: text[:price], font: DISPLAY, size: type_size[:price],
                color: theme.ink, y: pos[:price], align: align
        end

        # The button: a gradient plate with the label centred on it. Its own
        # group, so the label is placed against the plate and not the column.
        if pos[:cta]
          group y: pos[:cta], width: cta_box_width, height: cta_box_height, align: align do
            layer gradient: { from: theme.accent_hi, to: theme.accent, direction: :top_bottom }
            layer text: text[:cta], font: DISPLAY, size: column.cta_size,
                  color: theme.on_accent, align: :center, valign: :middle
          end
        end
      end

      # 8. The discount badge, after the artwork so it sits over its edge -- the
      #    overlap is what makes it read as applied to the product.
      if text[:badge]
        group x: badge_x, y: badge_y, width: badge_size, height: badge_size do
          layer solid: theme.accent
          vstack spacing: px[4], align: :center, distribute: :center do
            layer text: text[:badge], font: DISPLAY, size: type_size[:badge_value],
                  color: theme.on_accent
            if text[:badge_label]
              layer text: text[:badge_label], font: DISPLAY, size: type_size[:badge_label],
                    color: theme.on_accent, opacity: 0.7
            end
          end
        end
      end

      # 9. The benefits strip: a hairline across the full width with the small
      #    print sitting in the band under it. Full width on purpose -- it is
      #    the one element that belongs to the storefront rather than to the
      #    offer, and it reads that way when it ignores the column.
      if text[:note]
        layer solid: theme.ink, y: height - foot_height, width: width, height: 1, opacity: 0.16
        group x: frame[:pad], y: height - foot_height, width: width - (frame[:pad] * 2), height: foot_height do
          layer text: text[:note], font: SANS, size: type_size[:note],
                color: theme.muted, align: align, valign: :middle
        end
      end

      # 10. A brand bar across the top, tying the accent to the light behind the
      #     product.
      layer gradient: { from: theme.accent, to: theme.glow, direction: :left_right },
            width: width, height: [px[5], 3].max
    end
  end

  DEFAULT_COPY = {
    eyebrow: 'NEW SEASON · SUMMER 26',
    headline: 'Up to 40% off the whole store',
    subhead: 'Selected pieces, in the finish you already know, at a price that will not come round again.',
    price: 'from $199.90',
    cta: 'Shop the sale  →',
    note: 'FREE SHIPPING OVER $199 · EASY EXCHANGES · 30 DAYS TO RETURN',
    badge: '-40%',
    badge_label: 'OFF'
  }.freeze

  def parse_options(argv)
    options = { preset: 'hero', theme: 'midnight', out: 'banner.png', copy: DEFAULT_COPY.dup }

    OptionParser.new do |parser|
      parser.banner = "Usage: ruby #{File.basename(__FILE__)} [options]"

      parser.on('-p', '--preset NAME', "canvas: #{PRESETS.keys.join(', ')} (default hero)") { options[:preset] = _1 }
      parser.on('-t', '--theme NAME', "palette: #{THEMES.keys.join(', ')} (default midnight)") { options[:theme] = _1 }
      parser.on('-o', '--out PATH', 'output file, .png/.jpg/.webp (default banner.png)') { options[:out] = _1 }
      parser.on('-i', '--product PATH', 'product image; omitted, an abstract composition is drawn') do |path|
        options[:product] = path
      end

      DEFAULT_COPY.each_key do |field|
        parser.on("--#{field} TEXT", "#{field} text (an empty string drops it)") { options[:copy][field] = _1 }
      end

      parser.on('--all', 'render every theme at every preset into the --out directory') { options[:all] = true }
      parser.on('-h', '--help') do
        puts parser
        exit
      end
    end.parse!(argv)

    options
  end

  def fetch!(table, key, what)
    table.fetch(key) { abort "Unknown #{what}: #{key.inspect}. Available: #{table.keys.join(', ')}" }
  end

  # An empty string means "drop this block", which is not the same as leaving
  # the option off, so it becomes the nil the column already skips.
  def normalize(copy)
    copy.transform_values { |value| value.to_s.empty? ? nil : value }
  end

  def main(argv)
    options = parse_options(argv)
    copy = normalize(options[:copy])
    return render_matrix(options, copy) if options[:all]

    preset = fetch!(PRESETS, options[:preset], 'preset')
    theme = fetch!(THEMES, options[:theme], 'theme')

    render(options[:out], preset: preset, theme: theme, copy: copy, product: options[:product])
    puts "Wrote #{options[:out]} (#{preset.size.join('x')}, #{options[:theme]})"
  end

  # The contact sheet: every palette at every crop, which is the fastest way to
  # pick one and the fastest way to see what a change to the composition did.
  def render_matrix(options, copy)
    directory = options[:out] == 'banner.png' ? 'banners' : options[:out]
    FileUtils.mkdir_p(directory)

    THEMES.each_key do |theme|
      PRESETS.each_key do |preset|
        path = File.join(directory, "#{theme}-#{preset}.png")
        render(path, preset: PRESETS[preset], theme: THEMES[theme], copy: copy, product: options[:product])
        puts "Wrote #{path}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  require 'fileutils'
  EcommerceBanner.main(ARGV)
end
