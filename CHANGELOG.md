# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - unreleased

Restructure of the rendering pipeline. The public API — `Loomy.render`,
`Loomy.generate`, `Loomy.to_blob`, `Loomy.define_style`, `Loomy.register_effect`
— is unchanged. Every golden reference image renders pixel-identically except
`mockup_result.png`, which moves with the `contrast:` fix under Changed.

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
- `width:` and `height:` are checked too, against a union rather than a list: an
  Integer of pixels, a percentage String, or `:fill`. `width: :fil` and
  `width: '50'` used to reach layout as *no size at all*, so the node took the
  parent box and the mistake looked like it had worked.
- `Render::Trimmer`, and with it a choice of what `trim:` measures: `:alpha` for
  the extent of the pixels that are not fully transparent, `:color` for the old
  `find_trim` scan against a background colour, `:auto` to pick by whether the
  source has an alpha channel. `:auto` is the default and what `trim: true`
  means, so writing it out says the same as leaving it off, the way `fit:
  :contain` does. `bounds_of` takes the same modes, so what it
  reports and what `trim:` crops to cannot come apart. Both modes have a
  legitimate use — `:color` is the only one that can trim opaque artwork with a
  uniform border — and the bug was having no way to say which one you meant.
  The alpha scan is also the cheaper of the two: ~17ms against ~113ms on a
  4200x4800 source, paid once per source in the measure pass.
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
- `relight` takes `type: :soft` or `type: :hard`, checked against that
  vocabulary. This is the opposite case to `blend:`: Loomy owns these names and
  maps them onto a blend mode, so libvips never sees the one you wrote and
  cannot list the valid ones. Unchecked, an unknown type surfaced as a bare
  `KeyError` from inside the processor, half-way through a render.
- `adjust_color` and `relight` name the keyword arguments they accept, as `blur`
  already did, so `relight map: "m.png", strenght: 2` raises instead of being
  dropped into the property hash and ignored.

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
- `contrast:` pivots around mid-grey instead of being a second brightness. The
  two factors were folded into one gain — `linear([contrast * brightness], [0])`
  — so `contrast: 2.0` rendered exactly like `brightness: 2.0`, and
  `contrast: 0.5, brightness: 2.0` rendered exactly like no effect at all.
  `ColorAdjustment#no_op?` was conservative under the old maths and is exact
  under the new one. `mockup_result.png` moves with this.
- `relight`'s `strength:` scales the map towards mid-grey instead of being read
  by nothing but the pruner. Both blends leave a pixel alone where the map is
  mid-grey, so a flatter map is a weaker light; `strength: 1` renders
  byte-identically to before and `lighting.png` is unchanged.
- `Lighting#no_op?` is `strength.zero?`, matching `Displacement#no_op?`. It was
  `strength <= 0`, which now would prune a working effect: with the map scaled,
  a negative strength inverts the light rather than switching it off.
- `fit: :fill` is now `fit: :stretch`. `:fill` named two unrelated things in the
  same DSL — stretch to the declared box (`fit:`) and take the parent's box
  (`width:`/`height:`) — and the renderer collapsed both into `:stretch` on the
  way to the loader, so the unambiguous name already existed one layer down. The
  three fits are spelled the same in the DSL and in `Render::Target` now. There
  is no alias: `fit: :fill` raises `InvalidValue` listing the three.

### Fixed

- `trim:` could not see a white subject, and said nothing about it. It was
  libvips' `find_trim`, which measures distance from a background colour that
  defaults to **white**: a white subject on a transparent background is that
  background once flattened against it, so the whole image read as border and
  the scan came back empty. The empty result then fell through the
  `width.positive? && height.positive?` guards in `SourceLoader#load_trimmed`
  and `Layout::Engine#file_intrinsic` to the untrimmed image — a layer that
  asked to be trimmed, was not, and rendered as if it had been. Greyscale and
  CMYK sources missed for the same reason, which is the colourspace dependence
  the issue was opened about. `trim: true` now reads the alpha channel when the
  source has one, where colour cannot get the answer wrong, and falls back to
  the colour scan for artwork with no alpha to read. See Added for the modes.
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
- Effects treated alpha as one more colour band. `adjust_color brightness: 2.0`
  multiplied it too, so a half-opaque layer came back fully opaque (128 → 256,
  clipped to 255). `relight` composited the map straight over the image and took
  the map's opacity with it: a `#3366cc80` group came back `[14, 20, 37, 255]`
  instead of `[51, 102, 204, 128]`, and a group's empty margin came back painted
  flat grey.
- `relight` changed the picture even where its map was neutral, on anything
  translucent: compositing an opaque map over a translucent pixel leaves
  `(1-ab)·Cs` of the map's own colour behind. With alpha split off, a mid-grey
  map is an exact identity — which is what lets `strength` mean what it says.
- `adjust_color` was the only built-in that changed the band format, handing
  back `float` where it was given `uchar`. Values above 255 survived into the
  next composite and behaved as super-white there.
- `width: :fill` with no parent box to fill invented one. On a canvas with no
  `size:` the root box is `[nil, nil]`, and only percentages checked for that:
  `layer solid: "#f00", width: :fill, height: 50` rendered a 1x50 sliver,
  `width: :fill, height: :fill` rendered 1x1, and a file layer quietly came out
  at its own size. `:fill` is relative to the parent exactly as `"50%"` is, so it
  raises the same `LayoutError` naming the axis it could not resolve.
- `width: :fill` on a group or stack raised `TypeError: :fill can't be coerced
  into Integer` instead of filling. Only layers ever interpreted the sentinel; a
  container passed it through as the box its children measured against, so a
  percentage inside one failed with `NoMethodError: undefined method '*' for an
  instance of Symbol`. Both `group` and `vstack`/`hstack` expose `width:` and
  `height:`, so this was reachable from the documented DSL.

### Removed

- `Loomy::Planner::*`, `Loomy::Ops::*` and `Loomy::Engine::VipsBackend`. The
  operation graph was a second demand-driven layer on top of libvips, which is
  already demand-driven; `Planner::Optimizer` recomputed what `Planner::Builder`
  had already decided and made no measurable difference.
- `template`, `mask` and `artwork` on the canvas. They set a `role:` property
  that nothing read, making them aliases for `layer`.
- Unused accessors: `Layer#gravity`, `Effect#map_source`.
- `Lighting#type`'s `:ambient` default, which matched no blend mode and was read
  by nothing.

## [0.0.1]

- Initial release.
