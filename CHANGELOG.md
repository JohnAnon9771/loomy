# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - unreleased

Restructure of the rendering pipeline. The public API — `Loomy.render`,
`Loomy.generate`, `Loomy.to_blob`, `Loomy.define_style`, `Loomy.register_effect`
— is unchanged, and every golden reference image renders pixel-identically.

### Added

- `Layout::Engine`, a measure/arrange pass that resolves every node's size and
  position before any pixel work. Geometry used to be split across
  `Planner::Builder`, `Ops::Layer` and `Ops::Stack`.
- Main-axis distribution on stacks: `distribute:` accepts `:start`, `:center`,
  `:end` and `:space_between`. The old AST described `valign` as main-axis
  distribution in a comment, but nothing ever implemented it.
- `Loomy::Error` hierarchy that is actually raised: `SourceNotFound`,
  `InvalidColor`, `UnknownStyle`, `UnknownProperty`, `LayoutError`.
- `AST::Effect#no_op?`, so custom effects take part in pruning. Pruning used to
  dispatch through one hardcoded visitor method per built-in effect.
- `rake test:baseline` for regenerating golden references deliberately.

### Changed

- AST nodes are immutable. Rendering used to write layout results into the
  property hash it shared by reference with the AST, so rendering a tree twice
  gave different output.
- Each node kind has its own DSL builder. One builder served layers, groups and
  stacks, which is why `solid` was accepted on a group (and ignored) and a
  nested `layer` was accepted inside a leaf layer (and silently dropped).
- Sources are loaded straight at their final size, and the loader picks its
  strategy by format. `Vips::Image.thumbnail(path, …)` only helps for loaders
  with real shrink-on-load; for PNG and TIFF it decodes in full and then costs
  about twice as much as decoding and resizing directly. The two paths are
  pixel-identical.
- Trimming crops at full resolution and scales afterwards, instead of loading at
  twice the target width when that width happened to be below 1000.
- `Color` raises `InvalidColor` instead of returning opaque black, so a typo in
  a hex string no longer renders as a plausible-looking result.
- `required_ruby_version` is now `>= 3.2.0`. `Data.define` has been in use since
  before this release, so `>= 3.0.0` could never have worked.

### Fixed

- `to_blob` silently dropped `dpi`. Both it and `render` now share
  `Loomy::CANVAS_OPTIONS`.
- `Loomy::DSL::CanvasBuilder` and `Loomy::Bounds` were defined in
  `dsl/pipeline_builder.rb`, where Zeitwerk could not autoload them.
- `bench.rb` passed `blur:`/`grayscale:` as keyword arguments, so its
  "with effects" scenario applied no effects. The performance figures in the
  README have been remeasured.
- `bench.rb` and the test suite generated different images under the same
  filenames in `test/assets`, and `TrimTest#setup` rewrote a committed fixture
  on every run. Fixtures are committed; `test/fixtures_test.rb` pins them.
- `assert_image_similar` created a golden reference when one was missing, so a
  new visual test could never fail on its first run.

### Removed

- `Loomy::Planner::*`, `Loomy::Ops::*` and `Loomy::Engine::VipsBackend`. The
  operation graph was a second demand-driven layer on top of libvips, which is
  already demand-driven; `Planner::Optimizer` recomputed what `Planner::Builder`
  had already decided and made no measurable difference.
- `template`, `mask` and `artwork` on the canvas. They set a `role:` property
  that nothing read, making them aliases for `layer`.
- Unused accessors: `Layer#gravity`, `Effect#map_source`.

## [0.0.1]

- Initial release.
