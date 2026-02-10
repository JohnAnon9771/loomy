require_relative "base"
require "vips"

module Loomy
  module Ops
    class Load < Base
      attr_reader :path
      attr_accessor :target_width, :target_height, :crop_mode

      def initialize(path, target_width: nil, target_height: nil, crop_mode: nil)
        super(input: nil)
        @path = path
        @target_width = target_width
        @target_height = target_height
        @crop_mode = crop_mode
      end

      def call(context = nil)
        # Use cache if available
        cache = context.is_a?(Hash) ? context[:source_cache] : nil

        # 1. Exact Match Cache
        # Optimize cache key creation
        cache_key = @target_width || @target_height ? [@path, @target_width, @target_height, @crop_mode] : @path

        if cache && (cached_img = cache[cache_key])
          return cached_img
        end

        # 2. Raw Cache Fallback (Avoid re-reading disk if raw is already loaded)
        # If we need a resized version, but we already have the raw version in memory,
        # it is often faster to resize the in-memory image (especially for PNGs)
        # than to open the file again, even with Vips::Image.thumbnail.

        img = nil
        raw_key = @path

        if cache && (@target_width || @target_height) && (raw_img = cache[raw_key])
           # We have the raw image, generate thumbnail from it
           img = generate_thumbnail_from_image(raw_img)
        else
           # Load from disk
           img = load_image
        end

        if cache
          cache[cache_key] = img

          # If we just loaded the raw image (no target dimensions), ensure it's cached as raw key too
          # (Logic above handles this since cache_key == raw_key when no dimensions)
        end

        img
      end

      private

      def generate_thumbnail_from_image(img)
        if @crop_mode == :centre
          img.thumbnail_image(@target_width, height: @target_height, size: :both, crop: :centre)
        else
          img.thumbnail_image(@target_width || 10000, height: @target_height || 10000, size: :both)
        end
      end

      def load_image
        if @target_width || @target_height
          if @crop_mode == :centre
            Vips::Image.thumbnail(@path, @target_width, height: @target_height, size: :both, crop: :centre)
          else
            Vips::Image.thumbnail(@path, @target_width || 10000, height: @target_height || 10000, size: :both)
          end
        else
          img = Vips::Image.new_from_file(@path)
          img = img.bandjoin(255) unless img.has_alpha?
          img
        end
      end
    end
  end
end
