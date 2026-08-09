# frozen_string_literal: true

module Loomy
  # Registers the processors for the built-in effects.
  #
  # These go through the same public Loomy.register_effect that third-party
  # effects use, so nothing here is privileged.
  module EffectsRegistration
    def self.register_defaults
      Loomy.register_effect(AST::Effects::Blur, method(:blur))
      Loomy.register_effect(AST::Effects::ColorAdjustment, method(:adjust_color))
      Loomy.register_effect(AST::Effects::Grayscale, method(:grayscale))
      Loomy.register_effect(AST::Effects::Displacement, method(:displace))
      Loomy.register_effect(AST::Effects::Lighting, method(:relight))
    end

    # The level at which a map asks for nothing -- no displacement, no light --
    # and the point contrast pivots around.
    MID_GREY = 128.0

    # The libvips blend each lighting type washes its map over the image with.
    # The type names themselves are AST::Effects::Lighting::TYPES; picking a
    # blend for one is a pixel decision, so it lives here.
    LIGHT_BLENDS = { soft: :soft_light, hard: :hard_light }.freeze

    def self.blur(image, effect, _loader)
      image.gaussblur(effect.radius)
    end

    # Contrast expands the colour bands around mid-grey and brightness scales
    # what comes out of that, which together are one affine step: a gain of
    # contrast * brightness, plus the offset that leaves the pivot where it was.
    def self.adjust_color(image, effect, _loader)
      gain = effect.contrast * effect.brightness
      offset = MID_GREY * effect.brightness * (1 - effect.contrast)

      on_colour_bands(image) { |colour| colour.linear([gain], [offset]).cast(colour.format) }
    end

    def self.grayscale(image, _effect, _loader)
      on_colour_bands(image) { |colour| colour.colourspace(:b_w) }
    end

    # Warps the image by resampling it at coordinates pushed around by the map.
    #
    # A mid-grey map pixel means no displacement; darker pulls back along the
    # axis and lighter pushes forward, up to `scale` pixels. The map's first
    # band drives x and its second drives y, falling back to the first for a
    # single-band map.
    def self.displace(image, effect, loader)
      map = fitted_map(loader, effect.map, image).cast(:float)
      horizontal = displacement_band(map, 0, effect.scale)
      vertical = displacement_band(map, map.bands > 1 ? 1 : 0, effect.scale)

      image.mapim(Vips::Image.xyz(image.width, image.height) + horizontal.bandjoin(vertical))
    end

    def self.displacement_band(map, band, scale)
      (map.extract_band(band) - MID_GREY) / MID_GREY * scale
    end

    def self.relight(image, effect, loader)
      map = lighting_map(fitted_map(loader, effect.map, image), effect.strength)
      blend = LIGHT_BLENDS.fetch(effect.type)

      on_colour_bands(image) { |colour| lit(colour, map, blend) }
    end

    # `strength` scales the map around mid-grey rather than blending the lit
    # image back over the original. Both blends leave a pixel alone where the
    # map is mid-grey, so a flatter map is a weaker light: 1 is the map exactly
    # as it was read, below that softens, above hardens, and a negative one
    # inverts it. The cast is what makes strength 1 exact, and clamps the map
    # back into range past it.
    def self.lighting_map(map, strength)
      (((map - MID_GREY) * strength) + MID_GREY).cast(:uchar)
    end

    # libvips `composite` always hands back an alpha band and always calls the
    # result sRGB, even when neither input had either, so the colour bands come
    # back out in the shape they went in.
    def self.lit(colour, map, blend)
      colour.composite(map, blend).extract_band(0, n: colour.bands).copy(interpretation: colour.interpretation)
    end

    # Effect maps are stretched to cover the image they modulate. They go
    # through the loader like any other source, so a map used by two effects is
    # read once and an orientation tag on it is applied.
    def self.fitted_map(loader, path, image)
      loader.load_map(path, Render::Target.new(width: image.width, height: image.height, fit: :cover))
    end

    # Alpha is not a colour. A gain that brightens the picture would make a
    # translucent pixel opaque, converting to greyscale would drop the band
    # outright, and compositing over it would replace it with the map's -- which
    # also leaves the map's own colour behind wherever the image was
    # translucent, so a neutral map stopped being neutral. It is split off and
    # rejoined around the operation instead.
    def self.on_colour_bands(image)
      return yield(image) unless image.has_alpha?

      alpha = image.extract_band(image.bands - 1)

      yield(image.extract_band(0, n: image.bands - 1)).bandjoin(alpha)
    end
  end
end
