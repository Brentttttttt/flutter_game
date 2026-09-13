# WITCH KITTY

A cute mobile pixel-art survivor roguelike starring Witch Kitty. This extends the existing Flutter canvas game, with the original menu, two kitty palettes, joystick, finite arena, camera and retry flow.

## Play

Tap PLAY and choose the existing kitty color. Touch the arena to place a floating joystick, then drag to move. Its base stays at the initial touch; releasing immediately stops Kitty and hides the joystick. The original finger owns movement, so additional touches cannot shift it. Upgrade cards and other interactive UI take priority. Arcane Orbs automatically damage slimes. Collect dropped green gems to gain XP; after the level-up animation, choose one of three upgrades. Fire Orb is available as an upgrade and fires automatically at nearby slimes. Retry starts a completely fresh run.

- Slimes render at 48px, orbs at 24px, and Witch Kitty stays at 64px. Sprites use nearest-neighbor rendering. Impact and projectile rendering sizes are defined separately from combat hitboxes in `lib/game/rendering/vfx_layout.dart`; the level-up animation renders behind Kitty with its source ground anchor aligned to her world feet.
- Every slime randomly selects one of the seven `slime_v2` colors: Blue, Brown, Green, Grey, Orange, Red or Yellow. All colors share the same AI and combat stats. The original sheets are preserved in the project; gameplay loads the new artwork.
- Each defeated slime drops 5 XP. Gems persist until collected and latch onto the player inside the attraction radius.
- XP requirements follow `10 + 4 * (level - 1) + (level - 1)^2`: 10, 15, 22, 31, 42, ... Excess XP carries over, with a separate upgrade choice per level.
- Arcane Orbs cap at six. All owned orbs, including the Fire Orb, share a 58px radius and evenly spaced angles.
- Slime attacks lock their horizontal direction at the start, strike once at 0.4 seconds, finish at 0.8 seconds, and have a 1.25-second cooldown. Moving out of reach or behind the slime avoids the strike. Original left attack frames remain unchanged; only right attacks are mirrored around the same center.
- Fire Orb has five levels: unlock, +20% base projectile damage, -15% cooldown, one extra pierced enemy, +8 damage. Projectiles use swept collision and expire at 400px or two seconds.
- Combat, spawning, collection and survival time freeze during level-up/selection. App backgrounding stops the single ticker; selection and game-over screens keep it stopped.

Starting stats, weapon progression and visual budgets live in `lib/game/models/player_stats.dart`. Upgrade definitions/icons are in `lib/game/models/upgrade.dart`. Slimes spawned in the first 30 seconds have 20 HP and deal 6 damage; later spawns have 30 HP and deal 10 damage. Spawn pressure is configured in `lib/game/systems/enemy_spawner.dart`: the initial 2.8-second interval gradually shortens with survival time and player level, down to 0.9 seconds. The population starts at four, gains one slot every 20 seconds and every two gained levels, and caps at 24. Level contributions stop growing after 12 gained levels. Spawns arrive individually outside the camera with safe spacing; pauses and full populations never accumulate a burst. Effects, labels and projectiles are capped; persistent XP is culled only from offscreen drawing, never deleted for age.

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

Repository: **[Brentttttttt/flutter_game](https://github.com/Brentttttttt/flutter_game)**. It is public at the project owner's request and connected to GitHub Desktop. The existing repository name and remote were preserved.

```powershell
git push origin main
```

To open this existing checkout in GitHub Desktop, use **File > Add local repository** and select this folder, or run `github .` when Desktop's command is on PATH. Build outputs, local configuration, credentials, environment files, signing material and IDE caches are excluded from Git. Asset credits and unconfirmed licensing details remain in `ASSET_CREDITS.md`.
