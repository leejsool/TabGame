# TabGame — guide for AI sessions

Flutter game-hub app for Android tablets (also phones). Solo games + versus games (same device / CPU / same Wi-Fi).
The user is a non-developer: they give ideas and pick options; the AI does all the coding.
Talk to the user in plain Korean (no jargon). All UI text is Korean. App font: NanumGothic (`assets/fonts`).

## Folder map
- `lib/core/game_registry.dart` — `allGames`: one `GameInfo` per game (hub card, modes, tutorial, icon, records). New games register here.
- `lib/hub/` — hub screen, game cards, settings screen. `game_icons.dart` holds every drawn icon (`paint<Game>Icon`; grep, don't read it all).
- `lib/games/<game>/` — `core/` rules (pure Dart, tested without UI) → `game/` controller → `ui/` → `data/` history → `tutorial/`. Entry: `<game>_entry.dart`.
- `lib/versus/` — versus-game shared parts: `cpu_turn.dart` (`CpuTurnRunner`, CPU in an isolate), `vs_setup.dart` (setup screen kit).
- `lib/net/` — same-Wi-Fi play: `lan_screens.dart` (make/find room screens), `lan_connection.dart`, `keep_awake.dart`, `lan_stall_overlay.dart`.
- `lib/records/` — records screens; `vs_records.dart` (`VsRecordsBoard`) for versus games.
- `lib/tutorial/` — tutorial framework (`tutorial.dart`, `tutorial_screen.dart`) and `lesson_kit.dart` (교과학습).
- `test/<game>/` — tests; `preview_test.dart` renders PNG screenshots (see Commands).
- `tool/` — `test.ps1`, `build_dev.ps1`, art/sound prep scripts.

## Shared parts — reuse, don't copy
| Need | Use |
| --- | --- |
| Save / resume a game | `lib/core/game_save.dart` (`GameSave`), `resume_gate.dart` |
| "Leave? save?" / "new game?" confirms | `lib/core/leave_guard.dart` |
| Give up confirm | `lib/core/give_up.dart` |
| Win sound "짜잔" / click / game sfx | `win_sound.dart`, `click_sound.dart`, `sfx_pool.dart` (all in `lib/core/`) |
| History storage | `lib/core/json_history.dart` (`JsonHistoryStore`; record needs `toJson`/`fromJson`) |
| Versus setup / CPU / records | `VsSetupScaffold`, `VsChoiceCard`, `VsLevelPicker`; `CpuTurnRunner`; `VsRecordsBoard` |
| Playing cards | `lib/games/freecell/ui/playing_card.dart`, looks in `lib/core/card_look.dart` |
| Phone layout looks small on a tablet | `lib/core/tablet_scale.dart` (`TabletScale` scales the whole screen; `kTabletMinSide`) |
| Big win celebration | `lib/games/freecell/ui/win_celebration.dart` (cards), `lib/games/rummikub/ui/rummikub_celebration.dart` (general) |
If two games need the same widget, move it to a shared folder instead of copying it.

## New game checklist
Follow README "새 게임 추가 체크리스트". Also: add a drawn icon in `game_icons.dart`, add a `preview_test.dart`,
bump the version's middle number at release (see Release).

## Commands (Windows; user folder name is Korean, so temp must be an ASCII path)
- Fast tests: `powershell -ExecutionPolicy Bypass -File tool/test.ps1` (~2 min). One game: `... tool/test.ps1 test/<game>`. All incl. slow: `-All`.
- Direct `flutter test` needs `$env:TEMP=$env:TMP='F:\MyApp\tools\tmp'` first.
- Screenshots: set `$env:<GAME>_PREVIEW_DIR='<scratchpad dir>'` (e.g. `RUMMIKUB_PREVIEW_DIR`, `DAVINCI_PREVIEW_DIR`), then run `tool/test.ps1 test/<game>/preview_test.dart`; read the PNGs.
- Check sizes: phone 400x860, tablet portrait 800x1280, tablet landscape 1280x800. Tablet = shortestSide >= 600.
- Dev build to tablet: `tool/build_dev.ps1` (separate "개발" app). Release APK: `flutter build apk --release`.
- All tools live in `F:\MyApp\tools` (flutter, jdk, sdk, pub-cache, tmp). Never install tools elsewhere.

## Rules
- A button's `textStyle: TextStyle(...)` replaces the theme style, so it must include `fontFamily: 'NanumGothic'` (or start from `Theme.of(context).textTheme`). Same for `TextPainter`/`RichText` in painters. `test/core/app_font_test.dart` checks buttons.
- Lay out for both phone and the user's tablet (Galaxy Tab S9 FE, ~800x1280 dp). Check previews at all three sizes after UI changes.
- Sound effects: the user chooses sounds (`F:\MyApp\sfx`). Wire a sound only when asked.
- Ask before big or ambiguous changes; offer 2-3 options with a recommendation.
- Commit, push and release only when the user asks. Never `git add` `build/`, `.claude/`, `tool/art_src/_check_*.png`.
- The user often plays on the tablet (adb id `R54X401635E`). Don't tap, install or screencap via adb without asking.
- Keep new files under ~400 lines; split big screens by role (board, hand, bottom bar, dialogs).

## Release
- Version in `pubspec.yaml` (`x.y.z+N`). New game → bump middle (1.7.6 → 1.8.0); fixes only → bump last. Always bump `+N`.
- Sign with the standard key `F:\MyApp\key` (shared by all the user's apps; never commit it or print passwords).
- Steps: bump → commit → `flutter build apk --release` → push → `gh release create vX.Y.Z build/app/outputs/flutter-apk/app-release.apk#TabGame-X.Y.Z.apk` with Korean notes ("## 새로 생긴 것 / ## 고친 것"). The in-app updater reads the latest release.

## Saving tokens
- Grep first, then Read only the needed lines (`offset`/`limit`). Don't read whole large files (`rummikub_screen.dart`, `davinci_screen.dart`, `game_icons.dart`, `lan_screens.dart`).
- Run only the affected game's tests while working; run the full fast suite once before committing.
- Put design decisions the user makes into memory, not into long chat recaps.
