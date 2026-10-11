import 'package:flutter/material.dart';

/// 게임을 즐기는 방법.
enum PlayMode {
  solo('혼자 하기', '나 혼자 차분히 즐겨요', Icons.person),
  local2p('둘이서 (한 기기)', '태블릿 하나로 마주 앉아 대결해요', Icons.people),
  vsCpu('CPU와 대결', '컴퓨터를 상대로 혼자서도 대결해요', Icons.smart_toy);

  const PlayMode(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

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
  });

  final String id;
  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final List<PlayMode> modes;

  /// null이면 아직 만드는 중인 게임("준비 중"으로 표시).
  final GameScreenBuilder? builder;

  bool get isReady => builder != null;
  bool get hasSolo => modes.contains(PlayMode.solo);
  bool get hasMulti =>
      modes.contains(PlayMode.local2p) || modes.contains(PlayMode.vsCpu);
}
