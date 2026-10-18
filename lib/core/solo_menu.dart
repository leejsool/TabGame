import 'package:flutter/material.dart';

import '../records/records_screen.dart';
import 'game_widgets.dart';

/// 혼자 하기 게임의 첫 메뉴 틀: 위쪽 줄(제목 · 게임 방법 · 내 기록), 불러오는 동안의 빙글이, 가운데 정렬된 세로 목록.
/// 카드들(이어하기 · 튜토리얼 · 난이도 …)은 [children]으로 넘긴다. 폭은 [menuMaxWidth]를 따른다.
class SoloMenuScaffold extends StatelessWidget {
  const SoloMenuScaffold({
    super.key,
    required this.title,
    required this.onHelp,
    required this.recordsGame,
    required this.onRecordsClosed,
    required this.loaded,
    required this.children,
  });

  final String title;
  final VoidCallback onHelp;

  /// `내 기록`에서 처음 보여 줄 게임 id (`GameInfo.id`).
  final String recordsGame;

  /// 기록 화면에서 돌아왔을 때 (기록 요약을 다시 읽으려고) 부른다.
  final VoidCallback onRecordsClosed;
  final bool loaded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(tooltip: '게임 방법', icon: const Icon(Icons.help_outline_rounded), onPressed: onHelp),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: recordsGame);
              onRecordsClosed();
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !loaded
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: menuMaxWidth(context)),
                  child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: children),
                ),
              ),
      ),
    );
  }
}
