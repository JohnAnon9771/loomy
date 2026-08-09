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
  `InvalidColor`, `UnknownStyle`, `UnknownProperty`, `InvalidValue`,
  `LayoutError`.
- Values are checked against their vocabulary, not just property names.
  `align: :top`, `valign: :left`, `fit: :squish`, `trim: :yes`,
  `distribute: :around`, `stack(:sideways)`, a misspelled `anchor:` half and an
  unknown gradient `direction:` were all accepted and quietly ignored; each now
  raises `InvalidValue` naming what was expected. `blend:` is left to libvips,
  which validates its own enum and already lists the valid modes.
- `AST::Effect#no_op?`, so custom effects take part in pruning. Pruning used to
  dispatch through one hardcoded visitor method per built-in effect.
- `rake test:baseline` for regenerating golden references deliberately. A
  golden whose pixels have not moved is left on disk rather than re-encoded, so
  the diff to review names only the references that really changed.
- RubyCritic code-smell analysis (`rake critic`, `rake critic:console`), wired
  into CI behind a score floor. `.reek.yml` disables the detectors that only
  fire on this codebase's shape and documents why; the rest stay on.
- `Render::Target`, the size and fit a source has to be loaded at, replacing a
  `(width, height, fit)` trio threaded through five SourceLoader methods.

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
- Effect processors registered with `Loomy.register_effect` take a third
  argument, the render's source loader, so an effect that reads a map from disk
  goes through the same cache and orientation handling as everything else.
- `render` and `to_blob` stream the sources they can prove are read once, top to
  bottom, instead of decoding them whole. Two layers over a 4200x4800 source
  grow RSS by +69 MB instead of +142 MB. A source is only streamed when the
  tree says it is read exactly once and carries neither `trim:` nor a
  displacement; anything else keeps random access, because a streamed source
  read a second time fails outright. `generate` hands the image back for the
  caller to read as often as it likes, so it streams nothing.

### Fixed

- `to_blob` silently dropped `dpi`. Both it and `render` now share
  `Loomy::CANVAS_OPTIONS`.
- `Loomy::DSL::CanvasBuilder` and `Loomy::Bounds` were defined in
  `dsl/pipeline_builder.rb`, where Zeitwerk could not autoload them.
- Layout and rendering disagreed about EXIF-rotated sources. Measuring reads the
  header, which does not apply the orientation tag; libvips' `thumbnail` does
  apply it. A camera JPEG asked for 50x25 measured 50x25 and rendered 13x25.
  Orientation is now applied once, up front, and skipped for upright sources so
  it costs nothing in the common case.
- `bounds_of` opened the image itself instead of going through the loader, so it
  reported the frame the file is stored in while the render used the upright
  one: a 200x100 JPEG carrying orientation 6 answered 200x100 at (0,0) against a
  rendered 100x200. It also spelled its own trim threshold next to
  `SourceLoader::TRIM_THRESHOLD` and re-ran `find_trim` outside the per-render
  cache. It now measures through the loader, and accepts a `Pathname`.
- Displacement and lighting maps were read with a bare `Vips::Image` open, so a
  map used by two effects was decoded twice and an orientation tag on one was
  ignored.
- `fit: :contain`, the explicit spelling of the default, did not behave like the
  default: it took the "be exactly this box" path, so a layer's frame could
  claim 200x200 while the image was 175x200 and anything aligned against it
  landed off-centre.
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
