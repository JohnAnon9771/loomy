<p align="center">
  <img src="assets/logo.png" width="240" alt="Loomy Logo">
</p>

<h1 align="center">Loomy 🧶</h1>

<p align="center">
  <strong>The friendly pixel-weaver for Ruby.</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/loomy"><img src="https://img.shields.io/gem/v/loomy.svg" alt="Gem Version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="https://github.com/JohnAnon9771/loomy/actions"><img src="https://img.shields.io/badge/tests-passing-success.svg" alt="Tests Status"></a>
</p>

---

**Loomy** is a modern, high-performance image processing engine for Ruby. Think of it as a master weaver for your images: it takes raw layers (the threads) and weaves them into complex compositions using a smart, declarative DSL.

Built on top of `libvips`, Loomy resolves your whole composition — sizes, positions, load resolutions — before it touches a pixel, so every source is decoded exactly once, at exactly the size it ends up.

## 🚀 Key Features

- **Batch composition**: every layer is flattened in a single `libvips` composite call, not one composite per layer.
- **Layout before pixels**: a measure/arrange pass resolves geometry up front, so each source is loaded straight at its final size instead of being decoded and then resized.
- **Hierarchical Groups**: nest layers, groups and stacks to build complex layouts with shared effects.
- **Intelligent DSL**: declarative, block-based syntax. Each node kind accepts only what it can actually use, so typos and misplaced properties fail with a message instead of being ignored.
- **Extensible Effects**: register your own processors; custom effects take part in optimisation like the built-ins do.

### How a render runs

```
DSL  →  AST  →  Pruner  →  Layout (measure ⇢ arrange)  →  Renderer  →  Vips::Image
```

The AST is immutable, so a tree can be rendered more than once and always produces the same image. Layout writes its results to a side table of frames rather than back into the tree.

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'loomy'
```

And then execute:

```bash
bundle install
```

## 🛠 Usage

### 1. Generating Images

Loomy offers two ways to get your results: `render` (write to file) and `generate` (get a `Vips::Image` object).

#### Render to file

```ruby
Loomy.render("output.png", size: [1200, 630]) do
  layer "background.jpg"
end
```

#### Generate in-memory (Web Servers / Testing)

```ruby
# Returns a Vips::Image object
image = Loomy.generate(size: [1200, 630]) do
  layer "background.jpg"
end

# Get binary buffer for HTTP response or S3
buffer = image.write_to_buffer(".png")
```

### 2. Hierarchical Groups

Group layers to apply effects or positioning to a set of nodes collectively.

```ruby
Loomy.render("banner.png", size: [800, 400]) do
  group x: 50, y: 50 do
    layer "icon.png", width: 50
    layer "text.png", x: 60

    # Apply blur to the entire group
    blur radius: 2
  end
end
```

### 3. The Smart DSL

Forget about complex argument lists. Describe your image layout naturally:

```ruby
require 'loomy'

Loomy.render("output.png", size: [1200, 630]) do
  # Background
  layer "background.jpg" do
    fit :cover
    blur radius: 10
  end

  # Overlay
  layer "avatar.png" do
    x :center
    y :center
    width "20%"
    trim true # Auto-crop transparent borders
  end
end
```

### 4. Reusable Styles

Define common looks and apply them anywhere.

```ruby
# Define a style
Loomy.define_style :hero_layer do
  x 50
  y 100
  blend :overlay
end

Loomy.render("post.png", size: [1000, 1000]) do
  layer "texture.png" do
    use :hero_layer # Apply the style
    width 500       # Override or extend
  end
end
```

### 5. Stacks

Lay children out along an axis. `align`/`valign` set cross-axis alignment (whichever axis the children are *not* stacked along); `distribute` sets main-axis distribution.

```ruby
Loomy.render("card.png", size: [400, 600]) do
  vstack spacing: 16, align: :center, distribute: :space_between do
    layer "logo.png", width: 120
    layer text: "Sold out", size: 32, color: "#111"
    layer "footer.png", width: :fill
  end
end
```

### 6. Custom Effects & Registry

Define an effect node and register a processor for it:

```ruby
class Vignette < Loomy::AST::Effect
  def strength = properties[:strength] || 1.0

  # Optional: lets the pruner drop the effect when it cannot change a pixel.
  def no_op? = strength.zero?
end

Loomy.register_effect(Vignette, ->(image, effect, loader) {
  image.my_vips_operation(effect.strength)
})
```

The third argument is the render's source loader. An effect that reads a file
from disk — a displacement or lighting map, say — should ask it rather than
opening the file itself, so the read is cached for the render and any
orientation tag is applied:

```ruby
Loomy.register_effect(Overlay, ->(image, effect, loader) {
  target = Loomy::Render::Target.new(width: image.width, height: image.height, fit: :cover)

  image.composite(loader.load_map(effect.map, target), :over)
})
```

## ⚡ Performance

Measured with `bundle exec ruby bench.rb` on an Apple Silicon Mac, Ruby 3.3.6, libvips 8.18.5. Composition figures materialise the result to memory, because `libvips` is demand-driven and `Loomy.generate` on its own computes no pixels; the end-to-end figures include PNG encoding, which dominates at large sizes.

Reproduce them yourself — the benchmark is in the repository, and the numbers below are only as good as the machine they came from.

**Composition (1024×1024 canvas, no encoding)**

| Scenario                                              | Throughput |
| :---------------------------------------------------- | ---------: |
| 2 layers                                               | 430 img/s  |
| 5 layers, no effects                                   | 335 img/s  |
| 5 layers, with blur + grayscale                        | 204 img/s  |
| 4200×4800 source scaled to 200px inside a group        |  18 img/s  |

**End to end (render to PNG on disk)**

| Scenario                                     | Throughput |
| :------------------------------------------- | ---------: |
| 2 layers, 1024×1024                           |  91 img/s  |
| 3 layers, 4200×4800                           | 6.5 img/s  |
| Trim a 2000px source to its 500px of content  | 6.6 img/s  |

> An earlier version of this table reported "~70 img/s simple" and "~60 img/s complex (5+ layers + effects)". The benchmark behind those numbers passed `blur:` and `grayscale:` as keyword arguments, which are not how effects are declared — they landed in the property hash and were ignored, so the "with effects" figure was measured with no effects applied.

## 🗺 Roadmap

- [x] Percentage geometry (`width: "50%"`), resolved against the parent box
- [x] Main-axis distribution on stacks (`distribute:`)
- [ ] Viewport units (`vh`, `vw`)
- [ ] Rounded corners and masking
- [ ] SVG support as layers
- [ ] Smart Saliency Masking (Background Removal)

### Known limits

- `SourceLoader::NO_LIMIT` caps the unconstrained axis at 10,000px, so a source
  taller than that on its free axis is scaled down to fit the cap.
- `Loomy.styles` and `Loomy.effects` are process-global; registration is not
  thread-safe, so register at boot rather than per-request.

## 🚨 Errors

Everything Loomy raises descends from `Loomy::Error`, so one rescue covers it. Both halves of a declaration are checked: the property name, and its value.

```ruby
layer "art.png" do
  aling :center   # Loomy::UnknownProperty — no such property (lists what is available)
  align :top      # Loomy::InvalidValue    — :top belongs to the vertical axis
end
```

`align`, `valign`, `anchor`, `fit`, `trim`, `distribute`, a stack's `direction` and a gradient's `direction` all have closed vocabularies and say what they expected. `blend:` is left to libvips, which validates its own enum and lists the valid modes in its message.

## 🧪 Development

```bash
bundle exec rake test
```

```bash
bundle exec rubocop
```

Code smells, via [RubyCritic](https://github.com/whitesmith/rubycritic) (Reek + Flay + Flog + churn). `rake critic` opens an HTML report; `rake critic:console` prints to the terminal and is what CI runs. Both fail below a score floor set in the `Rakefile` — treat it as a ratchet: raise it when the score rises, never lower it to make a build pass.

```bash
bundle exec rake critic
```

Reek's defaults assume object-heavy application code, and Loomy is a pipeline of passes plus small value objects. `.reek.yml` turns off the detectors that only ever fire on that shape (`UtilityFunction`, `FeatureEnvy`, `DuplicateMethodCall`, `NilCheck`, `IrresponsibleModule`) and says why, in the file. Everything that pointed at something real is still on.

The analysis tools live in their own bundle group, so the test matrix does not install them:

```bash
BUNDLE_WITHOUT=lint bundle install
```

Golden reference images are only exactly reproducible on the libvips build they were rendered with (recorded in `test/test_helper.rb`). To regenerate them deliberately:

```bash
bundle exec rake test:baseline
```

### Known rough edge

`Layout::Engine` carries all of the geometry and RubyCritic flags it for size — 24 methods, and a `[node, box]` parameter pair threaded through eight of them. Splitting measure from arrange is awkward because they are mutually recursive (measuring a container arranges its children), so it wants its own change rather than a drive-by.

## 📄 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
