# World art

`world.js` is the single source of the Memory Garden's illustrations. Each picture is described once, as shapes with materials, and drawn in two styles:

- **The Den (MaoMao):** the garden at night, in pixel art. Each material has its own palette shading and ordered dithering. Scenery has no outlines; characters and icons have a 1px outline.
- **The Atelier (Salma):** the same garden in the morning, in ink and wash. It uses ink line, soft washes and hatching where there's shade.

What it draws:

| Art | Den | Atelier |
| --- | --- | --- |
| Garden map, 118 × 100 cells, with the six places | ✓ | ✓ |
| Stages for Journey, Gathering, Numbers, Kitchen, Lookout and Journal | ✓ | ✓ |
| Mascots in seven moods: idle, happy, thinking, cheer, oops, sleep, wave | Mochi, pixel | the Professor, ink |
| 27 pictograms, plus the item → pictogram map | pixels | engraved stipple |
| Stamps: ok, again, miss | ✓ | ✓ |

The playable canvas draws the art live from the same file, through `MG.world`. The iPhone app uses PNGs.

```sh
node distribution/art/build_art.js --check   # validate grids and the item → pictogram map
node distribution/art/build_art.js           # render App/Resources/Assets.xcassets/Art (+ art-manifest.json)
```

Rendering needs Playwright with Chromium. If they aren't resolvable from the repo, set `PLAYWRIGHT_PATH` and `CHROMIUM_PATH`.
