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

    def self.blur(image, effect)
      image.gaussblur(effect.radius)
    end

    def self.adjust_color(image, effect)
      image.linear([effect.contrast * effect.brightness], [0])
    end

    # Converting straight to :b_w would drop the alpha channel, so it is split
    # off and rejoined.
    def self.grayscale(image, _effect)
      return image.colourspace(:b_w) unless image.has_alpha?

      alpha = image.extract_band(image.bands - 1)
      rgb = image.extract_band(0, n: image.bands - 1)

      rgb.colourspace(:b_w).bandjoin(alpha)
    end

    # Warps the image by resampling it at coordinates pushed around by the map.
    #
    # A mid-grey map pixel (128) means no displacement; darker pulls back along
    # the axis and lighter pushes forward, up to `scale` pixels. The map's first
    # band drives x and its second drives y, falling back to the first for a
    # single-band map.
    NEUTRAL_DISPLACEMENT = 128.0

    def self.displace(image, effect)
      map = fitted_map(effect.map, image).cast(:float)
      horizontal = displacement_band(map, 0, effect.scale)
      vertical = displacement_band(map, map.bands > 1 ? 1 : 0, effect.scale)

      image.mapim(Vips::Image.xyz(image.width, image.height) + horizontal.bandjoin(vertical))
    end

    def self.displacement_band(map, band, scale)
      (map.extract_band(band) - NEUTRAL_DISPLACEMENT) / NEUTRAL_DISPLACEMENT * scale
    end

    def self.relight(image, effect)
      map = fitted_map(effect.map, image)

      image.composite(map, :soft_light)
    end

    # Effect maps are stretched to cover the image they modulate.
    def self.fitted_map(path, image)
      raise SourceNotFound, path unless path && File.readable?(path.to_s)

      Vips::Image
        .new_from_file(path.to_s)
        .thumbnail_image(image.width, height: image.height, size: :both, crop: :centre)
    end
  end
end
