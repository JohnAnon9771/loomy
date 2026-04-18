# frozen_string_literal: true

module Loomy
  module EffectsRegistration
    def self.register_defaults
      Loomy.register_effect(AST::Effects::Blur, lambda { |img, effect|
        img.gaussblur(effect.radius)
      })

      Loomy.register_effect(AST::Effects::ColorAdjustment, lambda { |img, effect|
        gain = effect.contrast * effect.brightness
        img.linear([gain], [0])
      })

      Loomy.register_effect(AST::Effects::Grayscale, lambda { |img, _effect|
        if img.has_alpha?
          alpha = img.extract_band(img.bands - 1)
          rgb = img.extract_band(0, n: img.bands - 1)
          rgb.colourspace(:b_w).bandjoin(alpha)
        else
          img.colourspace(:b_w)
        end
      })

      Loomy.register_effect(AST::Effects::Displacement, lambda { |img, effect|
        map =
          if effect.from_mask?
            mask = Vips::Image.new_from_file(effect.from_mask)
            mask = mask.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
            generate_displacement_map(mask, effect.intensity)
          else
            Vips::Image.new_from_file(effect.map_path).thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
          end

        if map.width != img.width || map.height != img.height
          map = map.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
        end

        if effect.from_mask?
          map = ensure_alpha(map, img)
          img = img.composite(map, :overlay, x: effect.scale, y: effect.scale)
        elsif img.respond_to?(:displace)
          img = img.displace(map, scale: effect.scale)
        else
          map = ensure_alpha(map, img)
          img = img.composite(map, :overlay, x: effect.scale, y: effect.scale)
        end

        img.format == :float ? img.cast(:uchar) : img
      })

      Loomy.register_effect(AST::Effects::Lighting, lambda { |img, effect|
        map =
          if effect.from_mask?
            mask = Vips::Image.new_from_file(effect.from_mask)
            mask = mask.thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
            generate_lighting_map(mask, effect.strength)
          else
            Vips::Image.new_from_file(effect.map_path).thumbnail_image(img.width, height: img.height, size: :both, crop: :centre)
          end

        img = if effect.from_mask?
          rgb = img.bands >= 4 ? img.extract_band(0, n: img.bands - 1) : img
          lighting_normalized = map / 128.0
          modulated = rgb * lighting_normalized
          modulated = modulated.bandjoin(img.extract_band(img.bands - 1)) if img.bands >= 4
          modulated.cast(:uchar)
        else
          blend_type = effect.type == :hard_light ? :hard_light : :soft_light
          img.composite(map, blend_type)
        end

        img.format == :float ? img.cast(:uchar) : img
      })
    end

    def self.generate_displacement_map(mask, intensity)
      heightmap = mask.colourspace(:b_w)
      scale = intensity * 2.0
      offset = 0.5 - (intensity * 0.5)
      normalized = heightmap.linear([scale], [offset])
      normalized.gaussblur(2)
    end

    def self.generate_lighting_map(mask, strength)
      lighting = mask.colourspace(:b_w)
      lighting * strength
    end

    def self.ensure_alpha(img, reference)
      if img.bands == 1 && reference.bands >= 3
        alpha = Vips::Image.black(img.width, img.height) + 255
        img = img.bandjoin(alpha)
      elsif reference.bands == 4 && img.bands == 3
        alpha = Vips::Image.black(img.width, img.height) + 255
        img = img.bandjoin(alpha)
      end
      img
    end
  end
end
