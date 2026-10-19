# TabGame — guide for AI sessions

Flutter game-hub app for Android tablets (also phones). Solo games + versus games (same device / CPU / same Wi-Fi).
The user is a non-developer: they give ideas and pick options; the AI does all the coding.
Talk to the user in plain Korean (no jargon). All UI text is Korean. App font: NanumGothic (`assets/fonts`).

## Folder map
- `lib/core/game_registry.dart` — `allGames`: one `GameInfo` per game (hub card, modes, tutorial, icon, records). New games register here.
- `lib/hub/` — hub screen, game cards, settings screen. `game_icons.dart` is only the `GameIcon` widget; each game's drawn icon lives in `lib/games/<game>/ui/<game>_icon.dart` (`paint<Game>Icon`, exported by `<game>_entry.dart`; pinball: `lib/games/pinball/`). Shared drawing helpers: `lib/hub/icon_kit.dart`.
- `lib/games/<game>/` — `core/` rules (pure Dart, tested without UI) → `game/` controller → `ui/` → `data/` history → `tutorial/`. Entry: `<game>_entry.dart`.
- `lib/versus/` — versus-game shared parts: `cpu_turn.dart` (`CpuTurnRunner`, CPU in an isolate), `vs_setup.dart` (setup screen kit).
- `lib/net/` — same-Wi-Fi play: `lan_screens.dart` (make/find room screens), `lan_connection.dart`, `keep_awake.dart`, `lan_stall_overlay.dart`.
  Rejoin (all Wi-Fi games; 2-player via `VsTwoPlayer`, 3+ via `LanHubKeeper`): `lan_rejoin.dart` (`LanRejoinDesk` keeps the room open after start, `LanHubKeeper` = host-side "CPU takes the seat / seat given back"), `lan_rejoin_flow.dart` (`RejoinTickets` saved on the guest, `lanRejoin`, drop dialog), `lib/hub/rejoin_cards.dart` (hub card). Each game controller has `coverSeat/uncoverSeat/wifiSnapshot/fromWifiSnapshot` in `*_controller_rejoin.dart`; `GameInfo.lanGame/lanResume` register it.
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
| Win sound "짜잔" / click | `win_sound.dart`, `click_sound.dart` (in `lib/core/`) |
| Game haptics + sounds per event | `lib/core/game_fx.dart`: each screen keeps `final GameFx _fx = GameFx({'drop': Fx(haptic: Haptic.light, sound: 'sfx/x.wav')})` and calls `_fx.play(context, kind)` from `onFeedback`. Adding a sound = one `sound:` entry. |
| Bottom tool-bar button, "이어하기" card | `GameBarButton`, `ResumeCard` in `lib/core/game_widgets.dart` |
| Finished-game row with ★ + "다시 하기" | `ReplayRecordTile` in `lib/records/record_widgets.dart` (also `StatCard`, `EmptyRecords`, `RecordsList`) |
| History storage | `lib/core/json_history.dart` (`JsonHistoryStore`; record needs `toJson`/`fromJson`) |
| Versus setup / CPU / records | `VsSetupScaffold`, `VsChoiceCard`, `VsLevelPicker`; `CpuTurnRunner`; `VsRecordsBoard` |
| Versus play screen parts | `lib/versus/vs_screen_parts.dart`: `VsGameScaffold` (portrait/landscape side panel), `VsTopBar`, `VsPlayerChip(s)`, `VsStatusBanner`, `VsBottomBar` + `VsButton` + `VsRematchButton`, `VsResultDialog`, `showVsRules`, `showVsNotice`, `confirmVsLeave`, `showOpponentResigned` |
| Two-player Wi‑Fi / rematch / leave / autosave logic | `lib/versus/vs_link.dart` mixin `VsTwoPlayer` (UTTT, Dandelion, Prophecy, Sprouts, Goblet use it; copy `uttt_screen.dart` as the template for a new 2-player game) |
| Playing cards | `lib/games/freecell/ui/playing_card.dart`, looks in `lib/core/card_look.dart` |
| Phone layout looks small on a tablet | `lib/core/tablet_scale.dart` (`TabletScale` scales the whole screen; `kTabletMinSide`) |
| Big win celebration | `showWinCelebration(context, title:)` in `lib/core/win_celebration.dart` — call next to `WinSound.play`; cards: `lib/games/freecell/ui/win_celebration.dart`; Rummikub/Sprouts/Mines keep their own |
| Solo game first menu | `SoloMenuScaffold` (`lib/core/solo_menu.dart`), `CardGrid`, `menuMaxWidth` (`game_widgets.dart`) |
| Waits / CPU think time | wrap in `GameSpeed.scale(...)` (`lib/core/game_speed.dart`; setting "빠른 진행") |
If two games need the same widget, move it to a shared folder instead of copying it.

## New game checklist
Follow README "새 게임 추가 체크리스트". **Every Wi-Fi (multiplayer) game must support leave/rejoin + CPU cover** (README step 5; `test/net/rejoin_registry_test.dart` fails if `lanGame`/`lanResume` is missing). Also: add a drawn icon in `game_icons.dart`, add a `preview_test.dart`,
bump the version's middle number at release (see Release).

## Commands (Windows; user folder name is Korean, so temp must be an ASCII path)
- Fast tests: `powershell -ExecutionPolicy Bypass -File tool/test.ps1` (~2 min). One game: `... tool/test.ps1 test/<game>`. All incl. slow: `-All`.
- Direct `flutter test` needs `$env:TEMP=$env:TMP='F:\MyApp\tools\tmp'` first.
- Screenshots of every screen at 3 sizes (+ phone dark, + `<name>_all.png` side by side): `tool/preview_all.ps1 [-Name "game (sudoku|mines)$"] [-Out <dir>]` (~1 min; add new games to `test/preview_all_test.dart`). Per-game scenario shots: `$env:<GAME>_PREVIEW_DIR='<dir>'` + `tool/test.ps1 test/<game>/preview_test.dart`.
- In tests call `loadAppFonts()` from `test/support/preview_kit.dart` (NanumGothic + Material icons); don't copy FontLoader code.
- Check sizes: phone 400x860, tablet portrait 800x1280, tablet landscape 1280x800. Tablet = shortestSide >= 600.
- Dev build to tablet: `tool/build_dev.ps1` (separate "개발" app). Release APK: `flutter build apk --release`.
- All tools live in `F:\MyApp\tools` (flutter, jdk, sdk, pub-cache, tmp). Never install tools elsewhere.

## Multiple PCs — paths differ per PC (check first!)
The user develops on several PCs; tool/key folders are not the same everywhere. **Before running any build or test, find out which layout this PC has** (`Test-Path F:\MyApp\tools`, `Test-Path C:\android\sdk`, `Test-Path C:\myapp\key`). Seen so far:
- PC A: tools in `F:\MyApp\tools` (the paths used in this file and in `tool/*.ps1`; `tool/test.ps1`, `build_dev.ps1`, `preview_all.ps1` hardcode them), key in `F:\MyApp\key`.
- PC B (school PC, project at `C:\myapp\tabgame`, no F: drive): sdk `C:\android\sdk`, key `C:\myapp\key`, ASCII temp `C:\ftmp`, pub cache `C:\pubcache`. The `tool/*.ps1` scripts do not work there — run the commands by hand.

**Root cause of most build/test failures on a PC: the Windows user folder name is Korean.** Anything that reads or writes under it breaks:
- `flutter test` crashes in `flutter_tester` → set `$env:TEMP=$env:TMP=<ASCII dir>` (e.g. `C:\ftmp`) first.
- `flutter build apk` fails with `:jni:buildCMakeRelWithDebInfo` / `ninja: error: FindFirstFileExA(c:/users/<한글>/appdata/local/pub/cache/hosted/pub.dev/jni-1.1.0/src)` → the default pub cache is under the Korean folder. Set `$env:PUB_CACHE=<ASCII dir>` (e.g. `C:\pubcache`) **before** `flutter pub get` and the build. The error never mentions "Korean path", so don't chase code.
- Release APK (PC B example): `$env:TEMP=$env:TMP='C:\ftmp'; $env:PUB_CACHE='C:\pubcache'; flutter pub get; flutter build apk --release`. `TABGAME_DEV` must NOT be set (it switches to debug signing + the ".dev" app id). Signing reads `<project>\..\key\keystore.properties` automatically; never print or commit it.
- Dev build to tablet by hand (same env + `$env:TABGAME_DEV='1'`, `flutter build apk --release --dart-define=TABGAME_DEV=true`, then `adb install -r`). Forgetting `TABGAME_DEV` as an env var overwrites the user's real release app on the tablet.
If a new PC has yet another layout, add a line to the list above.

## Rules
- A button's `textStyle: TextStyle(...)` replaces the theme style, so it must include `fontFamily: 'NanumGothic'` (or start from `Theme.of(context).textTheme`). Same for `TextPainter`/`RichText` in painters. `test/core/app_font_test.dart` checks buttons.
- Lay out for both phone and the user's tablet (Galaxy Tab S9 FE, ~800x1280 dp). Check previews at all three sizes after UI changes.
- Sound effects: the user chooses sounds (`F:\MyApp\sfx`). Wire a sound only when asked.
- Ask before big or ambiguous changes; offer 2-3 options with a recommendation.
- Commit, push and release only when the user asks. Never `git add` `build/`, `.claude/`, `tool/art_src/_check_*.png`.
- The user often plays on the tablet (adb id `R54X401635E`). Don't tap, install or screencap via adb without asking.
- Keep new files under ~400 lines; split big screens by role (board, hand, bottom bar, dialogs). Big screens/controllers are split with `part` files (`rummikub_screen.dart` + `_net/_flow/_layout/_fly/_table/_hand/_extras.dart`, same for davinci/quoridor/rummikub_controller): methods live in `extension` blocks, call `_update(() {...})` instead of `setState` there, and `_notify()` instead of `notifyListeners()`. Don't read all parts; grep the method name. (A `dynamic` receiver in a test can't see extension methods: cast it.)

## Release
- Version in `pubspec.yaml` (`x.y.z+N`). New game → bump middle (1.7.6 → 1.8.0); fixes only → bump last. Always bump `+N`.
- Sign with the standard key `F:\MyApp\key` (shared by all the user's apps; never commit it or print passwords).
- Steps: bump → commit → `flutter build apk --release` → push → `gh release create vX.Y.Z build/app/outputs/flutter-apk/app-release.apk#TabGame-X.Y.Z.apk` with Korean notes ("## 새로 생긴 것 / ## 고친 것"). The in-app updater reads the latest release.

## Saving tokens
- Grep first, then Read only the needed lines (`offset`/`limit`). Don't read whole large files (`rummikub_screen.dart`, `davinci_screen.dart`, `game_icons.dart`, `lan_screens.dart`).
- Run only the affected game's tests while working; run the full fast suite once before committing.
- Put design decisions the user makes into memory, not into long chat recaps.
