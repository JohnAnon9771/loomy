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

Built on top of `libvips`, Loomy doesn't just process images; it optimizes the entire "weaving" process (AST) to ensure your pipelines are as light and fast as silk.

## 🚀 Key Features

- **High Performance**: Built on `libvips` with a custom Batch Composition engine that flattens operations into a single efficient pipeline.
- **Hierarchical Groups**: Nest layers and groups to create complex layouts with shared effects.
- **Intelligent DSL**: Declarative, block-based syntax. Define properties naturally without complex argument lists.
- **AST Optimizer**: A smart "pre-weaving" layer that prunes invisible layers and pre-calculates geometry before rendering.
- **Extensible Effects**: Dynamic registry to add your own image processing strategies.

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

### 5. Custom Effects & Registry

Loomy is extensible. You can register your own `libvips` processors:

```ruby
# Register a custom effect
Loomy.register_effect(MyCustomEffectClass, ->(img, effect_node) {
  img.my_vips_operation(effect_node.param)
})
```

## ⚡ Performance

Loomy is designed for scale. Leveraging `libvips`' streaming architecture and our proprietary AST optimization, Loomy delivers exceptional throughput:

| Complexity                    | Throughput (M1) |
| :---------------------------- | :-------------- |
| Simple Composites             | ~70 images/sec  |
| Complex (5+ layers + effects) | ~60 images/sec  |

## 🗺 Roadmap

- [ ] Full support for relative geometry (`%`, `vh`, `vw`)
- [ ] Rounded corners and masking
- [ ] SVG support as layers
- [ ] Smart Saliency Masking (Background Removal)

## 📄 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
