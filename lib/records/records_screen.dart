import 'package:flutter/material.dart';

import '../games/freecell/ui/freecell_records_tab.dart';
import '../games/goblet/ui/goblet_records_tab.dart';
import '../games/jigsaw/ui/jigsaw_records_tab.dart';
import '../games/sudoku/ui/sudoku_records_tab.dart';

/// 게임별 기록 보드 모음. 새 게임이 기록을 갖게 되면 [_boards]에 한 줄만 추가하면 된다.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, this.initialGame = 'sudoku'});

  /// 처음에 보여줄 게임의 id (game_registry의 id).
  final String initialGame;

  static final List<({String id, String title, IconData icon, WidgetBuilder tab})> _boards = [
    (id: 'sudoku', title: '스도쿠', icon: Icons.grid_on_rounded, tab: (_) => const SudokuRecordsTab()),
    (id: 'freecell', title: '프리셀', icon: Icons.view_column_rounded, tab: (_) => const FreecellRecordsTab()),
    (id: 'jigsaw', title: '직소퍼즐', icon: Icons.extension_rounded, tab: (_) => const JigsawRecordsTab()),
    (id: 'goblet_gobblers', title: '고블렛', icon: Icons.layers_rounded, tab: (_) => const GobbletRecordsTab()),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _boards.indexWhere((b) => b.id == initialGame);
    return DefaultTabController(
      length: _boards.length,
      initialIndex: index < 0 ? 0 : index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 기록', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            tabs: [
              for (final b in _boards) Tab(icon: Icon(b.icon), text: b.title),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final b in _boards) b.tab(context)],
        ),
      ),
    );
  }
}

/// 기록 화면을 연다.
Future<void> openRecords(BuildContext context, {String game = 'sudoku'}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => RecordsScreen(initialGame: game)),
  );
}
