# Haven identity

Haven brings an agent to the work already on your Mac, then quietly takes care of the task in the background. Its logo is a soft, open **H** with two curious eyes: a small companion that stays close without demanding attention.

The supplied references inform the rounded silhouette, bright atmospheric color, satin highlights, and expressive face. This is an original H-shaped mark drawn as editable vectors.

## Files

- `haven-mark-dark.svg` / `haven-mark-light.svg`: primary marks with transparent eye cutouts, plus 1024 px PNGs.
- `haven-wordmark-dark.svg` / `haven-wordmark-light.svg`: horizontal logo lockups with custom outlined lowercase lettering; no font dependency.
- `haven-app-cyan.svg` / `.png`: primary app icon, 1024 px, transparent outside the macOS tile.
- `haven-app-mint`, `haven-app-coral`, `haven-app-gold`: alternate icon artwork with working, happy, and attentive expressions. These are design variants; the app ships with cyan.
- `Haven.icns` and `Haven.iconset/`: macOS icon representations from 16 px through 1024 px, including Retina sizes.
- `haven-menu-template.svg` and 18/36 px PNGs: silhouette only, optically enlarged for the menu bar.
- `haven-mark-animated.svg` / `haven-mark-animated-light.svg`: transparent animated logo, with CSS reduced-motion support.
- `haven-companion.gif`: portable animated app-icon preview. GIF cannot respond to reduced-motion settings; use the SVG or native/web component in interfaces.
- `haven-icon-family.png`: presentation image of the four app-icon variants.

## Use

Use the dark mark on light surfaces and the white mark on dark or vivid surfaces. Preserve its aspect ratio and leave at least 28 units of clear space around the 256-unit master. At small sizes use the silhouette-only menu template. Do not add colored artwork to the system menu bar: native `NSImage.isTemplate` lets macOS choose the correct appearance.

The primary palette is Daylight cyan `#00D7F4`, with Lagoon mint `#00E9BE`, Daybreak coral `#FF6080`, and Sunbeam gold `#F5D719`. The silhouette is ink `#141718`. Gradients and fine grain belong to app tiles and promotional artwork; the logo itself stays solid.

## Motion

The resting companion breathes over four seconds, lifting three master-coordinate units and scaling to 1.018 × 0.985 at the midpoint. A brief blink occurs at 44% of a 5.2-second cycle. The native and web components honor Reduce Motion. The menu icon remains static. The web preview also demonstrates working, done, and attention expressions and has a pause control.

The native app uses the animated mark on welcome and while tasks are running; its existing state label and colored dot continue to communicate task status.

## Source and regeneration

From the repository root, after installing the website dependencies:

```sh
node scripts/generate-brand.mjs
```

The generator uses Sharp from `site/node_modules`, creates all vector/raster exports and the macOS ICNS container, then updates the native image resource and website asset copies. Keep the silhouette in that script, `Sources/HavenUI/HavenLogo.swift`, and `site/components/haven-mark.tsx` synchronized when editing the design.

Preview the complete identity at `/brand` on the local site (`cd site && npm run dev`). Build the native app with `scripts/build-app.sh`; see `docs/packaging.md`.
