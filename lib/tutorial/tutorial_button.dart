import 'package:flutter/material.dart';

import 'tutorial.dart';

/// 게임 첫 화면(난이도 고르는 곳)에 놓는 "튜토리얼 보기" 버튼.
///
/// 처음 열 때 안내를 건너뛴 사람도 언제든 다시 볼 수 있게, 앱바의 작은 물음표 말고
/// 눈에 잘 띄는 넓은 버튼으로 둔다.
class TutorialButton extends StatelessWidget {
  const TutorialButton({super.key, required this.tutorial, this.onClosed});

  /// 게임의 안내 (예: `getColorTutorial`).
  final GameTutorial Function() tutorial;

  /// 안내 화면이 닫힌 뒤 (진행 표시 새로고침 등).
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final t = tutorial();
    return OutlinedButton.icon(
      onPressed: () async {
        await t.open(context);
        onClosed?.call();
      },
      icon: const Icon(Icons.school_rounded),
      label: const Text('튜토리얼 보기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: t.color,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: t.color.withValues(alpha: 0.6), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}
