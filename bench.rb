# frozen_string_literal: true

require 'benchmark/ips'
require 'fileutils'
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'loomy'

# Benchmark assets live under bench/tmp (gitignored) with names of their own.
# They used to be written into test/assets under the same filenames the test
# suite used, so whichever ran first decided what "base_large.png" meant.
TMP = File.expand_path('bench/tmp', __dir__)
FileUtils.mkdir_p(TMP)

def asset(name)
  File.join(TMP, name)
end

def build_asset(name)
  path = asset(name)
  return path if File.exist?(path)

  puts "Generating #{name}..."
  yield.cast(:uchar).write_to_file(path)
  path
end

BASE = build_asset('base_1024.png') do
  Vips::Image.black(1024, 1024, bands: 3).linear([1], [128, 128, 128]).bandjoin(255)
end

OVERLAY = build_asset('overlay_500.png') do
  Vips::Image.black(500, 500, bands: 3).linear([1], [255, 0, 0]).bandjoin(255)
end

BASE_LARGE = build_asset('base_4200x4800.png') do
  Vips::Image.black(4200, 4800, bands: 3).linear([1], [50, 50, 50]).bandjoin(255)
end

OVERLAY_LARGE = build_asset('overlay_2000.png') do
  Vips::Image.black(2000, 2000, bands: 3).linear([1], [0, 255, 0]).bandjoin(255)
end

TRIM_SOURCE = build_asset('trim_2000_with_500_content.png') do
  content = Vips::Image.black(500, 500, bands: 3).linear([1], [0, 0, 255]).bandjoin(255)
  content.embed(750, 750, 2000, 2000, extend: :background, background: [0, 0, 0, 0])
end

# libvips is demand-driven: Loomy.generate only assembles the pipeline, it does
# not compute pixels. Materialising to memory measures the composition engine
# without folding PNG encode time into the number.
def materialize(image)
  image.write_to_memory
end

puts
puts "ruby #{RUBY_VERSION} / libvips #{Vips.version(0)}.#{Vips.version(1)}.#{Vips.version(2)}"
puts

puts '== Composition only (generate + materialize, no encoding) =='
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('simple: 2 layers') do
    materialize(Loomy.generate(size: [1024, 1024]) do
      layer BASE
      layer OVERLAY, x: 200, y: 200
    end)
  end

  x.report('complex: 5 layers, no effects') do
    materialize(Loomy.generate(size: [1024, 1024]) do
      layer BASE
      layer OVERLAY, x: 50, y: 50, blend: :multiply
      layer OVERLAY, x: 400, y: 400, width: 200, height: 200, fit: :cover
      layer OVERLAY, x: 600, y: 100
      layer OVERLAY, x: 100, y: 600
    end)
  end

  # The old bench passed `blur: 5` / `grayscale: true` as keyword arguments.
  # Those are not effects — they landed in the property hash and were ignored,
  # so the "with effects" number was measured with zero effects applied.
  # Effects come from the block DSL.
  x.report('complex: 5 layers, with effects') do
    materialize(Loomy.generate(size: [1024, 1024]) do
      layer BASE
      layer OVERLAY, x: 50, y: 50, blend: :multiply
      layer OVERLAY, x: 400, y: 400, width: 200, height: 200, fit: :cover
      layer OVERLAY, x: 600, y: 100 do
        blur radius: 5
      end
      layer OVERLAY, x: 100, y: 600 do
        grayscale
      end
    end)
  end

  x.report('group: shrink-on-load inside a group') do
    materialize(Loomy.generate(size: [1000, 1000]) do
      layer OVERLAY
      group x: 100, y: 100, width: 400, height: 400 do
        layer BASE_LARGE, width: 200, height: 200
      end
    end)
  end

  x.compare!
end

puts
puts '== End to end (render to PNG on disk, includes encoding) =='
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('simple: 2 layers -> png') do
    Loomy.render(asset('out_simple.png'), size: [1024, 1024]) do
      layer BASE
      layer OVERLAY, x: 200, y: 200
    end
  end

  x.report('4k: 3 layers -> png') do
    Loomy.render(asset('out_large.png'), size: [4200, 4800]) do
      layer BASE_LARGE
      layer OVERLAY_LARGE, x: 500, y: 500
      layer OVERLAY, x: 100, y: 100
    end
  end

  x.report('trim: 2000px source, 500px content -> png') do
    Loomy.render(asset('out_trim.png'), size: [4200, 4800]) do
      layer BASE_LARGE
      layer TRIM_SOURCE, trim: true, x: 1000, y: 1000
    end
  end

  x.compare!
end
