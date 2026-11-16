# Calli brand kit

Mark 7-3 (Calli, Wenlong's minimal macOS writing app, Promethevs Labs; short for Calliope). Kit folder: `calli/kit/` (ships as `brand/`). The mark is letter-free: a single ensō-style brush stroke in the shape of a C. Only the lockups and banners carry the name.

The mark: one asymmetric ink stroke. The brush lands heavy at the upper left, sweeps round on a true circle (outer path fitted to a circle, width = height) and lifts at the lower right in a dry, split, flicked tail with a few fine specks. The opening faces the upper right.

## Palette

| Role | HEX | RGB |
|---|---|---|
| Paper | #FAF5EC | 250 245 236 |
| Ink (charcoal) | #1C1A1F | 28 26 31 |
| Cream (ink on dark) | #F5E6CF | 245 230 207 |
| Accent (not in the mark; for UI, optional) | #F25A12 | 242 90 18 |
| Mono cream / charcoal / black / white | #F5E6CF / #1C1A1F / #000000 / #FFFFFF | 245 230 207 / 28 26 31 / 0 0 0 / 255 255 255 |

Two versions of the same mark: **on paper** (ink #1C1A1F on paper #FAF5EC, `svg/mark-on-paper.svg`, `svg/mark-color-on-bg.svg`) and **on dark** (cream #F5E6CF on charcoal #1C1A1F, `svg/mark-on-dark.svg`). The transparent ink mark is `svg/mark-color.svg`. The lockup and banner name is set in cream on charcoal, or ink on paper.

## Typeface

Newsreader (Google Fonts, SIL OFL 1.1): Medium at the display optical size (opsz 72) for the name in lockups and banners, Regular at the text optical size (opsz 16) for text and captions. Newsreader is a calligraphic, screen-first text serif by Production Type: it has the warm pen-written contrast and quiet rhythm of a writing tool, so it suits a calm writing app and sits next to the ink stroke without competing with it. It is distinct from the other family typefaces (Cormorant, EB Garamond and Fraunces are already used by Constellations, Nous and Hermes). Names are outlined in every SVG/PDF; install the TTFs in `fonts/` for new text. Licence: `fonts/OFL.txt`.

## Rules

- Clear space: x = 0.25 x mark height (tight bounding box) on all sides.
- Minimum size: 24 px tall (digital) / 8 mm (print). Below that use `png/favicon-16.png` (or the macOS app icon sizes).
- Do: use the supplied files; keep clear space; cream on charcoal (or any dark), ink on paper (or any light).
- Don't: stretch or skew, recolour, add shadows/glow/gradients, redraw the stroke, or place on busy backgrounds.
- Avatars: `png/avatar-1024.png` (paper) and `png/avatar-dark-1024.png` (charcoal) are full-bleed with the stroke inside the central 82%, so they survive a circular crop.
- macOS app icon: `png/app-icon-macos-1024.png` is the approved squircle icon (824 px body, transparent margin); sizes 512, 256, 128, 64, 32, 16 are alongside.

## Files

### `png/`
Raster set: paper and on-dark avatars, macOS app icon (squircle) + sizes, logos, transparent marks (ink, cream, 3072 px ink-alpha raster master, paper source), favicons + .ico, apple-touch/PWA icons, maskable, social preview

`app-icon-macos-1024.png`, `app-icon-macos-128.png`, `app-icon-macos-16.png`, `app-icon-macos-256.png`, `app-icon-macos-32.png`, `app-icon-macos-512.png`, `app-icon-macos-64.png`, `apple-touch-icon-180.png`, `avatar-1024.png`, `avatar-500.png`, `avatar-dark-1024.png`, `avatar-dark-500.png`, `favicon-16.png`, `favicon-32.png`, `favicon-48.png`, `favicon.ico`, `icon-192.png`, `icon-512.png`, `logo-rounded-160.png`, `logo-rounded.png`, `logo-square-2048.png`, `logo-square-dark-2048.png`, `logo-square.png`, `mark-transparent-2048.png`, `mark-transparent-cream.png`, `mark-transparent.png`, `maskable-512.png`, `raster-master-ink-alpha-3072.png`, `raster-master-paper-source-1024.png`, `social-preview-1280x640.png`

### `svg/`
Vector masters (high-detail trace of the brush stroke): ink on paper, ink transparent, cream on charcoal, one-colour versions. One compound filled path per version

`mark-color-on-bg.svg`, `mark-color-onlight.svg`, `mark-color.svg`, `mark-mono-black.svg`, `mark-mono-charcoal.svg`, `mark-mono-cream.svg`, `mark-mono-white.svg`, `mark-on-dark.svg`, `mark-on-paper.svg`

### `pdf/`
Vector PDFs generated from the SVGs

`mark-color-on-bg.pdf`, `mark-color-onlight.pdf`, `mark-color.pdf`, `mark-mono-black.pdf`, `mark-mono-charcoal.pdf`, `mark-mono-cream.pdf`, `mark-mono-white.pdf`, `mark-on-dark.pdf`, `mark-on-paper.pdf`

### `mono/`
One-colour marks (cream #F5E6CF, charcoal #1C1A1F, black, white) as SVG and transparent PNG

`mono-black.png`, `mono-black.svg`, `mono-charcoal.png`, `mono-charcoal.svg`, `mono-cream.png`, `mono-cream.svg`, `mono-white.png`, `mono-white.svg`

### `lockups/`
Mark + name (set in Newsreader, outlined). Horizontal and stacked x dark / light / transparent (for dark use) / transparent-onlight, as SVG, PDF and PNG

`calli-horizontal-dark.pdf`, `calli-horizontal-dark.png`, `calli-horizontal-dark.svg`, `calli-horizontal-light.pdf`, `calli-horizontal-light.png`, `calli-horizontal-light.svg`, `calli-horizontal-transparent-onlight.pdf`, `calli-horizontal-transparent-onlight.png`, `calli-horizontal-transparent-onlight.svg`, `calli-horizontal-transparent.pdf`, `calli-horizontal-transparent.png`, `calli-horizontal-transparent.svg`, `calli-stacked-dark.pdf`, `calli-stacked-dark.png`, `calli-stacked-dark.svg`, `calli-stacked-light.pdf`, `calli-stacked-light.png`, `calli-stacked-light.svg`, `calli-stacked-transparent-onlight.pdf`, `calli-stacked-transparent-onlight.png`, `calli-stacked-transparent-onlight.svg`, `calli-stacked-transparent.pdf`, `calli-stacked-transparent.png`, `calli-stacked-transparent.svg`

### `banners/`
README banner 1280x320 and social preview with name 1280x640, both on dark (charcoal, cream ink)

`banner-readme-1280x320.png`, `banner-readme-1280x320.svg`, `social-preview-name-1280x640.png`, `social-preview-name-1280x640.svg`

### `fonts/`
Static TTFs for the name and body weights and the SIL OFL licence

`Newsreader-Medium.ttf`, `Newsreader-Regular.ttf`, `OFL.txt`

`brand-sheet.pdf`: one-page brand sheet (versions, palette, typeface, clear space, minimum size, dos and don'ts). `brand.md`: this file.

## Vector construction

Traced from the approved raster `calli/round7/7-3.png` (source `calli/work/raster-master-raw.png`, also in `png/raster-master-paper-source-1024.png`). The raw artwork was placed on the 1024 artboard with its outer path fitted to a circle (circle centred on the artboard, 1:1 aspect), converted to an ink-alpha map at 3x (3072 px), and traced at that resolution with a high-detail spline trace (speckles down to ~1.5 px at 1024 kept), so the dry bristle gaps, ragged edges and tail specks survive. The vector keeps the stroke as flat ink; the soft grey wash inside the stroke lives in the raster masters (`png/mark-transparent*.png`, `png/raster-master-ink-alpha-3072.png`). Node count: 11389 cubic Bezier segments, one compound path. Fidelity: 98% IoU against the raster ink mask.
