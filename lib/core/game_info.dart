import 'package:flutter/material.dart';

import '../net/lan_connection.dart';
import '../tutorial/tutorial.dart';

/// 게임을 즐기는 방법.
enum PlayMode {
  solo('혼자 하기', '나 혼자 차분히 즐겨요', Icons.person),
  local2p('둘이서 (한 기기)', '태블릿 하나로 마주 앉아 대결해요', Icons.people),
  vsCpu('CPU와 대결', '컴퓨터를 상대로 혼자서도 대결해요', Icons.smart_toy),
  wifi('같은 Wi‑Fi로 함께', '같은 공유기에 연결된 다른 기기와 대결해요', Icons.wifi);

  const PlayMode(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

/// 허브 카드·준비 중 화면에 그리는 아이콘 그림. 좌표는 0~1 안에서 그린다.
typedef GameIconPainter = void Function(Canvas canvas, double size);

/// 기록 화면에서 이 게임의 기록 보드를 만드는 함수.
typedef RecordsTabBuilder = Widget Function();

/// 게임 화면을 만드는 함수. 새 게임은 이 형태로 화면만 제공하면 허브에 붙는다.
typedef GameScreenBuilder = Widget Function(BuildContext context, PlayMode mode);

/// 허브(게임 목록)에 등록되는 게임 한 개의 정보.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.modes,
    this.builder,
    this.tutorial,
    this.iconPainter,
    this.iconImage,
    this.recordsTab,
    this.recordsTitle,
    this.hasLesson = false,
    this.lanGame,
    this.lanResume,
  });

  final String id;
  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final List<PlayMode> modes;

  /// null이면 아직 만드는 중인 게임("준비 중"으로 표시).
  final GameScreenBuilder? builder;

  /// 게임 방법 안내. 있으면 처음 열 때 한 번 자동으로 보여주고(건너뛰기 가능),
  /// 게임 메뉴의 도움말 버튼으로 언제든 다시 볼 수 있다.
  /// (그림을 그리는 함수가 들어 있어 const로 못 만드니, 만드는 함수를 받는다.)
  final GameTutorial Function()? tutorial;

  /// 직접 그린 아이콘 그림. [iconImage]나 이것이 없으면 [icon]을 대신 보여 준다.
  final GameIconPainter? iconPainter;

  /// 아이콘을 그림 파일로 보여 줄 때의 에셋 경로 ([iconPainter] 대신).
  final String? iconImage;

  /// 기록 보드. 있으면 "내 기록" 화면에 이 게임이 올라간다. (게임 안에서 `openRecords(context, game: id)`로 연다)
  final RecordsTabBuilder? recordsTab;

  /// 기록 화면의 게임 고르개에 보일 이름이 [title]과 다를 때 (좁은 칸에 맞춘 짧은 이름).
  final String? recordsTitle;

  /// 교과학습(단원별로 배우는 학습)이 있는 게임이면 true. 허브 카드에 학사모 표시가 붙는다.
  final bool hasLesson;

  /// 같은 Wi‑Fi에서 이 게임이 쓰는 이름 (방 찾기·"다시 들어오기 표"에 적힌 게임 이름). 같은 Wi‑Fi 게임은 반드시 채운다.
  final String? lanGame;

  /// 앱을 껐다 켠 뒤 하던 방에 다시 들어갈 때: 방장이 보낸 판의 모습(`resume`)으로 이 기기의 게임 화면을 만든다. 같은 Wi‑Fi 게임은 반드시 채운다 (`test/net/rejoin_registry_test.dart`가 확인한다).
  final Widget? Function(Map<String, dynamic> resume, LanConnection conn)? lanResume;

  bool get hasIconArt => iconPainter != null || iconImage != null;
  bool get hasRecords => recordsTab != null;
  bool get isReady => builder != null;
  bool get hasSolo => modes.contains(PlayMode.solo);

  /// 같은 Wi‑Fi로 함께 할 수 있는 게임이면 true. 허브 카드에 Wi‑Fi 표시가 붙는다.
  bool get hasWifi => modes.contains(PlayMode.wifi);
  bool get hasMulti =>
      modes.contains(PlayMode.local2p) || modes.contains(PlayMode.vsCpu) || modes.contains(PlayMode.wifi);
}
