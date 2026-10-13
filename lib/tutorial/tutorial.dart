import 'package:flutter/material.dart';

import 'tutorial_screen.dart';

/// 안내 화면 한 장: 그림 + 제목 + 설명.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    this.icon,
    this.art,
  });

  final String title;
  final String body;

  /// [art]가 없을 때 큰 그림 대신 보여줄 아이콘.
  final IconData? icon;

  /// 설명을 도와주는 그림. 칸 안에 맞게 크기가 조절된다.
  final Widget Function(BuildContext context, Color accent)? art;
}

/// 게임 하나의 "게임 방법" 안내.
///
/// 보통은 [steps]를 한 장씩 넘겨 보는 슬라이드이고, 스도쿠처럼 직접 해 보며 배우는
/// 안내는 [builder]로 자기 화면을 직접 만든다.
class GameTutorial {
  const GameTutorial({
    required this.title,
    required this.color,
    this.steps = const [],
    this.builder,
  });

  final String title;
  final Color color;
  final List<TutorialStep> steps;

  /// 슬라이드 대신 쓸 화면. [firstTime]은 게임을 처음 열 때 자동으로 뜬 것인지.
  final Widget Function(BuildContext context, {required bool firstTime})?
  builder;

  Widget screen(BuildContext context, {required bool firstTime}) =>
      builder?.call(context, firstTime: firstTime) ??
      TutorialScreen(tutorial: this, firstTime: firstTime);

  /// 안내 화면을 열고, 닫힐 때까지 기다린다.
  Future<void> open(BuildContext context, {bool firstTime = false}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => screen(ctx, firstTime: firstTime),
        ),
      );
}
