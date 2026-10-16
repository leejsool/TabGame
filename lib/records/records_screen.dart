import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/game_filter.dart';
import '../core/game_info.dart';
import '../core/game_registry.dart';


/// 게임별 기록 보드 모음. 보드는 게임 등록(`GameInfo.recordsTab`)에서 가져오니, 새 게임은 등록만 하면 여기에 올라온다.
///
/// 게임이 늘어도 글자가 잘리지 않도록 탭 줄 대신 "게임 고르개"를 쓴다: 위쪽에 지금 보는 게임의 이름이 통째로
/// 보이고, 누르면 모든 게임이 격자로 나오는 목록이 열린다. (양옆 화살표로 이웃 게임으로도 넘어간다)
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, this.initialGame = 'sudoku'});

  /// 처음에 보여줄 게임의 id (game_registry의 id).
  final String initialGame;

  /// 기록 보드가 있는 게임들 (등록 순서).
  static final List<GameInfo> boards = [for (final g in allGames) if (g.hasRecords) g];

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late int _index = () {
    final i = _boards.indexWhere((b) => b.id == widget.initialGame);
    assert(i >= 0, "기록 보드가 없는 게임 id: '${widget.initialGame}' (game_registry의 recordsTab을 확인하세요)");
    return i < 0 ? 0 : i;
  }();

  List<GameInfo> get _boards => RecordsScreen.boards;

  void _go(int i) => setState(() => _index = (i + _boards.length) % _boards.length);

  Future<void> _pick() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => _GamePicker(boards: _boards, selected: _index),
    );
    if (chosen != null) _go(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final board = _boards[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 기록', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(tooltip: '이전 게임', onPressed: () => _go(_index - 1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Material(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pick,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(board.icon, color: scheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                board.recordsTitle ?? board.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text('${_index + 1}/${_boards.length}', style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6))),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(tooltip: '다음 게임', onPressed: () => _go(_index + 1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(top: false, child: KeyedSubtree(key: ValueKey(board.id), child: board.recordsTab!())),
    );
  }
}

/// 게임을 고르는 목록 (격자). 게임이 아무리 많아져도 스크롤되고, 이름은 두 줄까지 통째로 보인다.
///
/// 위의 분류 막대(전체·혼자·함께·Wi‑Fi·교과학습)로 거를 수 있다. 분류는 게임 등록 정보로 저절로 정해지고
/// ([GameFilter]), 같은 Wi‑Fi로 할 수 있는 게임에는 이름 옆에 Wi‑Fi 표시가 붙는다.
class _GamePicker extends StatefulWidget {
  const _GamePicker({required this.boards, required this.selected});

  final List<GameInfo> boards;
  final int selected;

  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  GameFilter _filter = GameFilter.all;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // (게임 전체에서의 번호, 게임) — 거른 뒤에도 고른 게임의 원래 번호를 돌려주려고
    final shown = [for (var i = 0; i < widget.boards.length; i++) if (_filter.matches(widget.boards[i])) (i, widget.boards[i])];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('어느 게임의 기록을 볼까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GameFilterBar(selected: _filter, onChanged: (f) => setState(() => _filter = f)),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Text('이 분류에 맞는 게임이 아직 없어요', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
          )
        else
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisExtent: 104,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: shown.length,
              itemBuilder: (context, k) {
                final (i, game) = shown[k];
                final on = i == widget.selected;
                return Material(
                  color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, i),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(game.icon, size: 30, color: on ? scheme.primary : scheme.onSurface.withValues(alpha: 0.75)),
                                const SizedBox(height: 6),
                                Text(
                                  game.recordsTitle ?? game.title,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, height: 1.2, fontWeight: on ? FontWeight.w900 : FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (game.hasWifi && !kIsWeb)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Tooltip(
                              message: '같은 Wi‑Fi로 함께 할 수 있어요',
                              child: Icon(Icons.wifi_rounded, size: 16, color: scheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 기록 화면을 연다.
Future<void> openRecords(BuildContext context, {String game = 'sudoku'}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => RecordsScreen(initialGame: game)),
  );
}
