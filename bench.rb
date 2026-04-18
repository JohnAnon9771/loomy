# frozen_string_literal: true

require 'benchmark/ips'
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'loomy'

# Ensure assets are generated
unless File.exist?('test/assets/base.png')
  Vips::Image.black(1024, 1024, bands: 3).linear(
    [1],
    [128, 128,
     128]
  ).bandjoin(255).cast(:uchar).write_to_file('test/assets/base.png')
end

unless File.exist?('test/assets/overlay.png')
  Vips::Image.black(500, 500, bands: 3).linear(
    [1],
    [255, 0,
     0]
  ).bandjoin(255).cast(:uchar).write_to_file('test/assets/overlay.png')
end

# Large assets (4200x4800)
unless File.exist?('test/assets/base_large.png')
  puts 'Generating large base asset (4200x4800)...'
  Vips::Image.black(4200, 4800, bands: 3).linear(
    [1],
    [50, 50,
     50]
  ).bandjoin(255).cast(:uchar).write_to_file('test/assets/base_large.png')
end

unless File.exist?('test/assets/overlay_large.png')
  puts 'Generating large overlay asset (2000x2000)...'
  Vips::Image.black(2000, 2000, bands: 3).linear(
    [1],
    [0, 255,
     0]
  ).bandjoin(255).cast(:uchar).write_to_file('test/assets/overlay_large.png')
end

unless File.exist?('test/assets/trim_source_large.png')
  puts 'Generating large trim asset...'
  # 2000x2000 image with 500x500 content in middle, rest transparent
  content = Vips::Image.black(500, 500, bands: 3).linear([1], [0, 0, 255]).bandjoin(255)
  padded = content.embed(750, 750, 2000, 2000, extend: :background, background: [0, 0, 0, 0])
  padded.cast(:uchar).write_to_file('test/assets/trim_source_large.png')
end

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('simple_composite') do
    Loomy.render('bench_output_simple.png', size: [1024, 1024]) do
      layer 'test/assets/base.png'
      layer 'test/assets/overlay.png', x: 200, y: 200
    end
  end

  x.report('complex_composite') do
    Loomy.render('bench_output_complex.png', size: [1024, 1024]) do
      layer 'test/assets/base.png'
      layer 'test/assets/overlay.png', x: 50, y: 50, blend: :multiply
      layer 'test/assets/overlay.png', x: 400, y: 400, width: 200, height: 200, fit: :cover
      layer 'test/assets/overlay.png', x: 600, y: 100, blur: 5
      layer 'test/assets/overlay.png', x: 100, y: 600, grayscale: true
    end
  end

  x.report('large_composite_4k') do
    Loomy.render('bench_output_large.png', size: [4200, 4800]) do
      layer 'test/assets/base_large.png'
      layer 'test/assets/overlay_large.png', x: 500, y: 500
      layer 'test/assets/overlay.png', x: 100, y: 100 # Mixing sizes
    end
  end

  x.report('trim_composite') do
    Loomy.render('bench_output_trim.png', size: [4200, 4800]) do
      layer 'test/assets/base_large.png'
      # This image is 2000x2000 but only has 500x500 content.
      # With trim: true, it should act like 500x500 image.
      layer 'test/assets/trim_source_large.png', trim: true, x: 1000, y: 1000
    end
  end

  x.compare!
end

# Cleanup outputs (keep inputs for re-runs)
['bench_output_simple.png', 'bench_output_complex.png', 'bench_output_large.png', 'bench_output_trim.png'].each do |f|
  File.delete(f) if File.exist?(f)
end
