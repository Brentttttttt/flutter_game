# Verification

## Endless-mode update — 2026-09-14

Flutter 3.44.6 / Dart 3.12.2. `flutter analyze` reports no issues and
`flutter test` passes all **97** unit, widget and rendering tests. Formatting is
clean. `flutter pub get` and `flutter pub outdated` succeed; direct dependencies
are current and remaining transitive versions are constrained by this SDK.

The new tests cover five-minute scheduling, a six-second warning, no overlapping
bosses, paused milestone timers, both weapons damaging Dino Tri, telegraphed
one-hit attacks and dodging, the half-HP enraged phase, stronger later bosses,
boss defeat awarding XP while the same run continues, gradual slime recovery,
bounded later spawn pressure, low-health sound hysteresis and full retry reset.
Audio tests cover exact WAV mappings/headers, fades, stale transition cancellation,
native-backend failure handling, bounded/throttled sound requests, pause/UI sound
behavior, independent volume/mute controls and persisted settings. Both cosmetic
attires and menu/selection meows remain covered by widget tests.

All eight Dino sheets are decoded and checked against their 384 × 128 frame
layout. Reviewed the real rendered poses in both directions, including green/red
attack effects and the Thought splash. The body stays upright and fixed around
its authored ground origin. Updated UI captures show readable portrait sound
settings, boss warning, boss health/enrage and boss counts on Game Over.

The Android integration test **passes** on the Pixel 3 API 33 emulator, using
the real native audio backend and production widgets/world. It advances survival
time and arranges encounters **only inside
the test**, so a complete recurring-boss check does not require ten minutes of
manual play. Production entry points have no debug shortcuts or altered timers.
Reviewed rendering-test captures live under ignored `build/verification/`.
The native test also exercises PNG rendering into its private temporary directory
without storage permissions; Flutter removes that test installation on exit.

Native coverage includes all five actual BGM files, menu/attire meows, successful
Arcane and Fire hits, boss warning/music transitions requested by the real UI,
boss HP/enrage, player damage, boss XP with no victory/end-of-run transition,
a stronger second encounter, death statistics, retry, pause/settings/resume, and
error-free audio shutdown. Playback-position polling is disabled because no game
UI consumes it; native resource disposal can be awaited. A physical-device check
remains useful for speaker balance and touch feel.

The original emulator had insufficient free space for the audio-bearing debug
APK. Native verification used a separate fresh data image under ignored `build/`
without removing unrelated apps or wiping the original emulator's data.

`tool/build_release.ps1` successfully built the production `lib/main.dart` APK:
**161,255,906 bytes (153.8 MiB)**, including the supplied uncompressed WAV music.
`app-release.apk` and `witch_kitty.apk` in `build/app/outputs/flutter-apk/` have
identical SHA-256 `1716311D3068A0F4A2822C6072A23DAC5944CCEC17BEC2141EF96C212CE89122`.
APK inspection confirms exactly five BGM tracks, twelve SFX files, all eight Dino
sheets and all seven `slime_v2` sheets, with zero legacy slime sheets. The label
is `Witch Kitty`, the adaptive icon resolves correctly, and the existing technical
identifier and development signing configuration are preserved.

Installed and opened this release APK, inspected the real launcher icon/name,
menu, both attire choices and a fresh purple-attire arena with colored slimes.
Release logs show no Flutter or AndroidRuntime errors. Native screenshots are in
ignored `build/verification/android/release_*.png`.

## Previous progression and slime release — 2026-09-13

Verified locally with Flutter 3.44.6 / Dart 3.12.2.

- `flutter doctor -v`: Android toolchain available; no issues.
- `flutter pub get` and `flutter pub outdated`: all directly resolvable dependencies current. Newer transitive releases are constrained by the installed Flutter SDK; no forced upgrades.
- `flutter analyze`: no issues.
- `flutter test`: all 69 tests pass, including seven-color slime animation/rendering, time-and-level spawn pressure, floating touch input, VFX layers and the complete gameplay flow.
- `flutter build apk --release`: successful, approximately 42.8 MB. Normal output remains `build/app/outputs/flutter-apk/app-release.apk`; readable copy is `witch_kitty.apk` in the same directory.
- APK manifest inspection reports application label `Witch Kitty`, existing identifier `com.example.flutter_game`, and the configured adaptive launcher icon. Decoded packaged launcher/foreground PNG pixels match the new source resources exactly. The updated APK contains all seven `slime_v2` sheets and excludes the old slime sheets. The standard and readable-name APK files have identical SHA-256 hashes.
- APK installed on the Pixel 3 API 33 Android emulator. Visually verified the custom icon and `Witch Kitty` label in its app drawer, opened the game from that icon, used PLAY and color selection, collected XP, chose Fire Orb and further upgrades, reached level 4, died and retried to full HP / level 1 / zero XP and kills. This play session prompted gentler opening slimes (20 HP / 6 damage for spawns before 30 seconds), covered by the final passing tests and rebuilt APK. The host's software-rendered emulator initially suffered an Android System UI ANR, then recovered after reducing its display load. Deterministic gameplay and visual flow checks below ran in Flutter's rendering/test engine. A physical-device play session remains useful for touch feel and device-specific performance.
- The subsequent `slime_v2` release was rebuilt and installed successfully on the same emulator. The new sprites appeared with multiple randomized colors, correct death bursts, XP collection and upgrade choices. Selected Fire Orb at level 2 and captured its actual traveling projectile and a slime death in the installed app. Reached level 5 and 23 kills, then Game Over at 58 seconds while standing still. Retry restored 100 HP, level 1, zero XP/kills, one Arcane Orb and an invisible idle joystick. Android logs showed no Flutter or AndroidRuntime errors during this check.

## Gameplay coverage

Tests exercise the existing main menu, color selection and gameplay transition; normalized movement and arena/camera bounds; slime pursuit, locked left/right attack facing, windup, one hit per swing, cooldown, dodging and death; actual orb hits and per-enemy cooldown; one persistent XP drop per death, attraction acceleration, collection and scalable XP thresholds; gameplay freeze throughout level-up and choice; unique three-card offers, carryover XP and one applied choice per level; every stat upgrade and both weapon caps; evenly spaced orbs; Fire Orb targeting, swept first-enemy collision, piercing and range/lifetime expiry; capped feedback; app lifecycle pauses; death, retry and fresh run state with a single ticker.

## Visual review

`flutter test test/visual_review_test.dart` writes PNGs in ignored `build/verification/`. Inspected the real menu, 320px portrait HUD, XP/combat feedback, transparent centered level-up effect, three readable cards with Kyrise icons, game-over/retry, Fire Orb projectile and left/right attack comparison. The right attack is the same frame mirrored horizontally about its center; the original left attack remains intact. The projectile uses the upward-facing ShotLoop artwork rotated to its direction of travel.

The current slime artwork is `slime_v2`: all seven 320×128 sheets were decoded and every 32px cell alpha-audited. Animation rows contain 6/6/9/9 occupied frames; blank padding is excluded. `test/slime_v2_test.dart` covers random color selection without altering upgrade randomness, shared movement/combat and complete attack/death playback. `test/slime_v2_rendering_test.dart` compares rendered opaque pixels with the actual selected color/action source, including horizontal mirroring. Inspected all 42 panels in `12_slime_v2_colors_and_actions.png` and the two-sided attack comparison. Sprite size remains 48px and attack/death durations remain unchanged.

`test/vfx_rendering_test.dart` also captures real Arcane hits, traveling Fire Orb projectiles and fire impacts at several animation frames. Arcane impact and fire shot destination sizes are 96px; fire explosions are 104px. The 192px level-up animation sits behind Kitty with the authored ground anchor aligned to her world feet. Rendered pixel comparisons across three animation frames and two player/camera positions verify that opaque Kitty pixels remain visible and the aura follows the player. Inspected `10_level_up_layers_and_world_anchor.png` and `11_arcane_and_fire_vfx_sizes.png` in `build/verification/`.

The floating joystick is hidden until a gameplay touch, retains that touch's screen-space origin, clamps its knob and normalizes diagonal input. Tests cover the deadzone, owning pointer, release/cancel, camera movement, upgrade/menu/retry touch priority and app lifecycle reset. An Android playtest also captured the idle, held diagonal drag and released states; the joystick appeared at the initial touch and disappeared on release.

The icon composition was inspected at full size and in the adaptive safe area. It uses original Witch Kitty pixels, a purple orb and a midnight background. It is reproducible with `flutter test tool/generate_launcher_icon.dart`.

## Spawn progression

Tests verify that time and level each increase pressure, first-30-second levels 1–4 stay at no more than six slimes with intervals of at least 1.9 seconds, the live world passes its current level into the spawner, and long frames or full populations never produce catch-up bursts. Existing offscreen placement and spacing checks remain in force.

| Survival / player level | Spawn interval | Maximum slimes |
| --- | --- | --- |
| 0s / 1 | 2.80s | 4 |
| 30s / 4 | 1.94s | 6 |
| 60s / 5 | 1.63s | 9 |
| 120s / 7 | 1.23s | 13 |
| 240s / 10 | 0.90s | 20 |
| 360s / 13 | 0.90s | 24 |

## Repository

No repository or remote existed initially. Initialized `main` and created the initial commits. The repository was subsequently published through GitHub Desktop as `Brentttttttt/flutter_game`. At the project owner's explicit request, its visibility was changed to public; the existing repository and origin URL were preserved. Confirmed the repository page is accessible without authentication and opened the local checkout in GitHub Desktop. Staged text was checked for common private-key and credential-token patterns; staged paths were checked for environment files, local configuration and signing material. None were found. Build and review outputs remain ignored.

No asset licenses/readmes were supplied locally. Every unconfirmed license/source is explicitly marked in `ASSET_CREDITS.md`; no license terms were assumed. The APK retains the project's existing debug-key release signing configuration for development installation.
