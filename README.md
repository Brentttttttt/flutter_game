# WITCH KITTY

A cute mobile pixel-art survivor roguelike starring Witch Kitty. This extends the existing Flutter canvas game, with the original menu, two kitty palettes, joystick, finite arena, camera and retry flow.

## Play

Tap PLAY, choose the existing kitty color, and drag the lower-left joystick. Arcane Orbs automatically damage slimes. Collect dropped green gems to gain XP; after the level-up animation, choose one of three upgrades. Fire Orb is available as an upgrade and fires automatically at nearby slimes. Retry starts a completely fresh run.

- Slimes render at 48px, orbs at 24px, and Witch Kitty stays at 64px. Sprites use nearest-neighbor rendering.
- Each defeated slime drops 5 XP. Gems persist until collected and latch onto the player inside the attraction radius.
- XP requirements follow `10 + 4 * (level - 1) + (level - 1)^2`: 10, 15, 22, 31, 42, ... Excess XP carries over, with a separate upgrade choice per level.
- Arcane Orbs cap at six. All owned orbs, including the Fire Orb, share a 58px radius and evenly spaced angles.
- Slime attacks lock their horizontal direction at the start, strike once at 0.4 seconds, finish at 0.8 seconds, and have a 1.25-second cooldown. Moving out of reach or behind the slime avoids the strike. Original left attack frames remain unchanged; only right attacks are mirrored around the same center.
- Fire Orb has five levels: unlock, +20% base projectile damage, -15% cooldown, one extra pierced enemy, +8 damage. Projectiles use swept collision and expire at 400px or two seconds.
- Combat, spawning, collection and survival time freeze during level-up/selection. App backgrounding stops the single ticker; selection and game-over screens keep it stopped.

Starting stats, weapon progression and visual budgets live in `lib/game/models/player_stats.dart`. Upgrade definitions/icons are in `lib/game/models/upgrade.dart`. Slimes spawned in the first 30 seconds have 20 HP and deal 6 damage; later spawns have 30 HP and deal 10 damage. Spawning begins gently with four active enemies, grows by one every 20 seconds to a cap of 24, and gradually shortens its interval. Effects, labels and projectiles are capped; persistent XP is culled only from offscreen drawing, never deleted for age.

## Develop and build

Requires a Flutter SDK compatible with Dart 3.12.2 and an Android SDK. No external runtime packages are used.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
./tool/build_release.ps1
```

The build helper preserves Flutter's normal output and copies it to `build/app/outputs/flutter-apk/witch_kitty.apk`. The visible Android/iOS/Windows name is **Witch Kitty**; technical identifiers remain unchanged for installation compatibility. The existing Android release configuration uses the local debug signing key for installable development releases. Configure your own private release signing separately before store distribution; signing keys are ignored by Git.

Regenerate launcher resources from the existing sprite artwork:

```powershell
flutter test tool/generate_launcher_icon.dart
```

`test/visual_review_test.dart` saves native-rendered review images under ignored `build/verification/`. `docs/ASSET_LAYOUTS.md` documents audited dimensions, source rectangles and animation frame counts. See `ASSET_CREDITS.md` for asset ownership and license verification items before distributing the game or assets.

## GitHub

The project uses a private repository by default to avoid publishing third-party assets accidentally. If GitHub CLI is unavailable or unauthenticated, install GitHub CLI, authenticate, and run from this folder after the local commit:

```powershell
gh auth login
gh repo create witch-kitty --private --source=. --remote=origin --description "A cute mobile pixel-art survivor roguelike starring Witch Kitty." --push
```

If a remote has since been configured, preserve it and use `git push -u origin main` instead of creating a duplicate. Build outputs, local configuration, credentials, environment files, signing material and IDE caches are excluded from Git.
