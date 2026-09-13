# Verified local sprite layouts

Coordinates are zero-based pixels in the original PNGs. Sprite source rectangles
use `(x, y, width, height)`. All inspected PNGs decode as RGBA. Use nearest-neighbor
sampling (`FilterQuality.none`) and preserve each frame's aspect ratio. A source
image's hidden RGB values do not indicate an opaque background: use its alpha
channel.

These findings come from dimensions, image/alpha inspection, comparisons with
individual frames, and the supplied Aseprite metadata. Animation playback speeds
are game choices except where the Aseprite timings are explicitly stated below.

## XP gem

- File: `assets/xp-gem/xp.png`, **64 × 16**.
- Four **16 × 16** frames across one row: frame `i` is `(16*i, 0, 16, 16)`.
- All four frames are the same animated **green** faceted gem. The supplied pack
  file does not include a blue/cyan variant. Use the original green gem so XP
  comes from the requested La Red Games asset rather than an unrelated atlas.
- Its background has zero alpha; the gem pixels are fully opaque.

## Level-up effect

- File: `assets/level-up-effect/Level Up Effect Spritesheet.png`, **1536 × 128**.
- Twelve **128 × 128** frames in one horizontal row.
- Frame `i` is `(128*i, 0, 128, 128)`.
- Every cell exactly matches its corresponding supplied `Level Up Effect
  Frame1.png` through `Level Up Effect Frame12.png` (each **128 × 128**).
- Frame 0 is intentionally completely transparent. Later frames include authored
  partial alpha for the fading wings/sparkles; preserve that transparency.
- The effect is centered on source X=64. The authored wings occupy roughly
  source Y=70–106, and the ground arc Y=118–121. Use the fixed source ground
  anchor `(64,120)` aligned to Kitty's world feet, `player.position + (0,28)`.
  The destination is a uniform 192px square (1.5×), drawn behind Kitty without
  rotation, flipping, per-frame cropping or anchor changes. Centering the whole
  128px source canvas on Kitty would incorrectly lower the wings.

## Orb impact effect

- Files: `assets/orbs/orb-hit-effect/{blue,green,grey,purple,red}/`
  `{color}-spritesheet.png`, each **512 × 384**.
- Grid cells are **128 × 128**, four columns.
- **Only eight cells contain animation:** indices 0–7 in the first two rows.
  All four cells in the third row are fully transparent padding.
- Frame `i` is `(128*(i % 4), 128*(i ~/ 4), 128, 128)` for `i = 0..7`.
- Purple is suitable for Arcane Orb hits. Frame 7 is a deliberately faint fade;
  retain its alpha and remove the effect after the sequence completes.
- The visual destination is 96px square, up from 64px (1.5×), centered on the
  recorded contact point. Damage and collision radii are independent.
- Invisible RGB data is purple even where alpha is zero. Do not flatten the
  original PNG onto a background or treat RGB color as an opacity mask.

## Fire Ball pack

All files are in `assets/orbs/fire-orb-projectile/`. Every frame is **64 × 64**,
in one horizontal row, so frame `i` is `(64*i, 0, 64, 64)`.

| Actual filename | Image size | Frames | Visible purpose |
| --- | --- | --- | --- |
| `Creation-Sheet.png` | 896 × 64 | 14 | Fireball formation |
| `IdleLoop-Sheet.png` | 256 × 64 | 4 | Resting flame loop |
| `ShootAntecipation-Sheet.png` | 192 × 64 | 3 | Pre-shot animation; filename spelling preserved |
| `ShotLoop-Sheet.png` | 256 × 64 | 4 | Traveling fire projectile |
| `Explode-Sheet.png` | 448 × 64 | 7 | One-shot impact/explosion |

The shot loop points **up** in its source artwork (tail below the bright core).
For a heading measured with `atan2(dy, dx)`, rotate the source by `heading + pi/2`.
The actual flame occupies approximately 10 × 17 pixels inside the 64 × 64 canvas,
around x=32 and y=35. Preserve the shared canvas anchor between frames. The
explosion expands around the same center rather than filling its entire canvas.
Shot rendering uses a 96px square (1.5× the previous visual size); explosion
rendering uses a 104px square (1.625×). Both preserve the original aspect ratio
and nearest-neighbor sampling. Projectile damage, speed, range, lifetime and
collision behavior remain unchanged.

## Existing orb atlas

- File: `assets/orbs/orbs-sheet.png`, **192 × 176**.
- **16 × 16** cells, 12 columns and 11 rows (132 cells).
- Index `n` maps to `(16*(n % 12), 16*(n ~/ 12), 16, 16)`.
- **Arcane Orb:** outlined purple animation, indices **60–67**, eight frames.
  This is the existing game's selection and remains the appropriate choice.
- **Fire Orb:** outlined red/orange animation, indices **47–51**, five frames.
  This wraps from row 3 column 11 to row 4 columns 0–3.
- Indices 42–46 are a separate unoutlined Fire Orb variant. Do not combine
  indices 42–51 as a ten-frame animation: its outline would change halfway.
- Indices 52–59 are the separate unoutlined purple variant.
- The atlas also contains other coin, gem, water, green and grey animations;
  their presence does not establish the atlas's original pack or license.

## Kyrise upgrade icons

The supplied `assets/upgrade-icons/` has **350 PNGs per directory** at `16x16/`,
`32x32/` and `48x48/`, for 1,050 images total. Each file is one icon rather than a
sprite sheet, and its dimensions match its directory. Some larger variants differ
from simple nearest-neighbor scaling, so load the intended resolution explicitly.

Suitable inspected icons under `assets/upgrade-icons/16x16/`:

| Upgrade | File | Visual meaning |
| --- | --- | --- |
| VITALITY | `potion_01a.png` | Red healing vial; no heart icon is supplied |
| SWIFT PAWS | `boots_01c.png` | Cyan boot |
| ARCANE POWER | `staff_01c.png` | Blue-tipped magic staff |
| ORB HASTE | `ring_01d.png` | Gold ring suggesting circular motion |
| MAGNETISM | `crystal_01c.png` | Blue faceted gem |
| ARCANE ORB | `gem_01j.png` | Purple magic crystal matching the Arcane Orb |
| FIRE ORB | `pearl_01c.png` | Red sphere matching the Fire Orb |

These are actual supplied filenames; no replacement icons are needed.

## Current slime_v2 enemies

Files are in `assets/characters/enemies/slime_v2/`: `Slime_Blue.png`,
`Slime_Brown.png`, `Slime_Green.png`, `Slime_Grey.png`, `Slime_Orange.png`,
`Slime_Red.png` and `Slime_Yellow.png`. All seven are **320 × 128**, arranged
as ten columns and four rows of **32 × 32** cells. Alpha inspection confirms:

| Animation | Row | Used columns | Frames |
| --- | --- | --- | --- |
| Idle | 0 | 0–5 | 6 |
| Walk | 1 | 0–5 | 6 |
| Attack | 2 | 0–8 | 9 |
| Death | 3 | 0–8 | 9 |

Frame `i` in row `r` is `(32*i, 32*r, 32, 32)`. Trailing cells are transparent
padding and must not enter the animation loop. Render complete cells into the
existing 48px square, preserving the fixed center, aspect ratio and original
transparency. The attack artwork faces left; right-facing attacks mirror that
same frame horizontally around the destination center. No vertical flip or
rotation is needed.

The attack still strikes at 0.4 seconds, finishes at 0.8 seconds and observes
the existing 1.25-second cooldown. Nine attack frames are mapped across that
duration; the nine death frames play across the existing 0.6-second death
duration. Frame count changes therefore do not change combat timing. Cosmetic
color selection is random for each spawn and separate from upgrade randomness.
Every color shares the same behavior, hitbox, HP, damage and XP rules.

Only PNGs were supplied in this new folder; no timing metadata, creator or
license document was present. See the separate `slime_v2` credit entry.

## Previous Animated Slime (retained, unused by gameplay)

Files are in `assets/characters/enemies/slime/`. Every frame is **64 × 64**,
in a horizontal row, and every corresponding `.ase` source specifies **100 ms
per frame** (10 fps).

| PNG | Size | Frames | Purpose |
| --- | --- | --- | --- |
| `Stanby.png` | 896 × 64 | 14 | Idle; original spelling preserved |
| `walk E1.png` | 256 × 64 | 4 | East walk |
| `walk w1.png` | 256 × 64 | 4 | West walk |
| `Walk N1.png` | 256 × 64 | 4 | North walk |
| `Walk S1.png` | 256 × 64 | 4 | South walk |
| `Atack.png` | 512 × 64 | 8 | Left-facing attack; original spelling preserved |
| `Death.png` | 384 × 64 | 6 | Death |
| `sleeping.png` | 320 × 64 | 5 | Unused sleeping animation |
| `Sleeps.png` | 512 × 64 | 8 | Unused sleep animation |

These previous assets remain unmodified in the repository. Their separate
directional walking sheets and 64px source rectangles are no longer loaded by
the game; the current renderer uses the `slime_v2` row layout above.

## Existing player artwork

All player frames use a **64 × 64** source canvas and row-major sheet indexing.

| Actual path relative to `assets/characters/player_character/` | Size | Grid / cells |
| --- | --- | --- |
| `color_1/witchKitty_walk.png` | 256 × 256 | 4 × 4 / 16 |
| `color_1/witchKitty_curiousIdleBreaker.png` | 192 × 256 | 3 × 4 / 12 |
| `color_1/witchKitty_sleepyIdleBreaker.png` | 192 × 320 | 3 × 5 / 15 |
| `color_2/calicoKitty_walk.png` | 256 × 256 | 4 × 4 / 16 |
| `color_2/calicoKitty_curiousIdleBreaker.png` | 320 × 128 | 5 × 2 / 10 |
| `color_2/calicoKitty_sleepyIdleBreaker.png` | 320 × 192 | 5 × 3 / 15 |

Walking uses four frames for each existing direction row. The curious-idle sheets
are the existing game's idle sources. Sleepy sheets are retained in the project.
Launcher artwork should use the actual Witch Kitty `color_1` art without stretching
the character or adding tiny text.

## Launcher composition and regeneration

The launcher icon is rendered by the project's own Flutter Canvas utility:

```powershell
flutter test tool/generate_launcher_icon.dart
```

This explicit generation command is outside `test/` so routine tests never
rewrite platform resources. It does not require a launcher-icon dependency or an
external image service. It draws Witch Kitty's first curious-idle frame
`(0, 0, 64, 64)` and the existing outlined purple orb `(0, 80, 16, 16)` with
`FilterQuality.none`. Both retain their original square aspect ratio and pixel
colors on a flat `#332047` background. The original source PNGs are unchanged.

- Android legacy `ic_launcher.png` and `ic_launcher_round.png`: 48, 72, 96, 144,
  192 pixels in mdpi through xxxhdpi.
- Android adaptive `ic_launcher_foreground.png`: 108, 162, 216, 324, 432 pixels,
  representing a 108dp transparent foreground. All visible pixels are within the
  central 66dp-diameter safe circle (verified maximum radius: 32.94dp).
- Android API 26+ adaptive definitions: `mipmap-anydpi-v26/ic_launcher.xml` and
  `ic_launcher_round.xml`, with background from `values/colors.xml`. The app
  manifest references the normal and round launcher resources.
- iOS: the existing `AppIcon.appiconset/Contents.json` defines all exported sizes;
  every matching PNG is replaced with the composition and has fully opaque alpha.
- Windows: `windows/runner/resources/app_icon.ico` contains PNG entries at
  16, 24, 32, 48, 64, 128 and 256 pixels.
- Review preview: [witch_kitty_icon.png](witch_kitty_icon.png).

The adaptive dimensions and safe-circle convention follow the
[Android adaptive icon documentation](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
Android/iOS display names and the Windows window/product title are `Witch Kitty`;
technical package identifiers and executable names remain unchanged.

## Existing tiles and font previews

- `assets/tileset/tiles.png`: **80 × 240**, a **5 × 15** grid of 16 × 16 tiles.
  Existing floor source is `(16, 64, 16, 16)`. Existing boundary tiles occupy
  columns 0–2 and rows 6–8, starting at `(0, 96)`.
- `assets/font/characters.png`: **887 × 640**, font reference image.
- `assets/font/characterpreview.png`: **887 × 481**, font preview image.
- `assets/font/friendlyscribbles.ttf`: existing UI font, family
  `friendlyscribbles`, Regular, embedded Version 2 and copyright `kmlgames`.
  The PNGs are references rather than a replacement bitmap-font atlas.

See [ASSET_CREDITS.md](../ASSET_CREDITS.md) for the unverified licensing items.
