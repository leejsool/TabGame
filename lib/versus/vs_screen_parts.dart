import 'package:flutter/material.dart';

import '../records/records_screen.dart';

// 대결 게임(CPU와 / 둘이서 / 같은 Wi‑Fi) 플레이 화면의 공통 부품.
// 게임마다 다른 것(판, 선수 그림, 문구)만 넘기면 모양과 동작이 모든 대결 게임에서 같아진다.

/// 윗줄: 뒤로 · 제목 · (교과학습) · 내 기록 · 규칙.
class VsTopBar extends StatelessWidget {
  const VsTopBar({super.key, required this.title, required this.gameId, required this.onRules, this.onLesson});

  final String title;

  /// 기록 화면에서 이 게임을 여는 id ([openRecords]).
  final String gameId;
  final VoidCallback onRules;

  /// 교과학습이 있는 게임만.
  final VoidCallback? onLesson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          // 제목이 남는 폭을 모두 쓴다 (빈 칸과 나눠 갖지 않아 폰에서도 잘리지 않는다)
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (onLesson != null) IconButton(tooltip: '교과학습', icon: const Icon(Icons.menu_book_rounded), onPressed: onLesson),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: gameId)),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: onRules),
        ],
      ),
    );
  }
}

/// 선수 칩 하나: 지금 차례면 진하게 강조된다.
class VsPlayerChip extends StatelessWidget {
  const VsPlayerChip({super.key, required this.icon, required this.label, required this.color, required this.active, this.trailing});

  /// 선수를 나타내는 작은 그림 (22~24 크기).
  final Widget icon;
  final String label;
  final Color color;

  /// 지금 차례이거나 (끝난 판에서) 이긴 쪽이면 true.
  final bool active;

  /// 이름 뒤에 붙일 것 (예: 끝난 판의 점수).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: active ? 1 : 0.3), width: active ? 2.5 : 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// 선수 칩 줄 (좁으면 다음 줄로 넘어간다).
class VsPlayerChips extends StatelessWidget {
  const VsPlayerChips({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 12, runSpacing: 6, alignment: WrapAlignment.center, children: chips),
    );
  }
}

/// 차례 안내 띠. [color]는 지금 차례인 선수의 색 (끝났으면 회색).
class VsStatusBanner extends StatelessWidget {
  const VsStatusBanner({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

/// 아래 단추 줄 (좁은 화면·옆 칸에서는 단추가 다음 줄로 넘어간다).
class VsBottomBar extends StatelessWidget {
  const VsBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: children),
    );
  }
}

/// 아래 줄의 테두리 단추 (되돌리기 · 새 판 · 기권 · 힌트 …).
class VsButton extends StatelessWidget {
  const VsButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// 같은 Wi‑Fi 대결이 끝난 뒤의 "한 판 더" 단추. 서로 눌러야 새 판이 시작된다.
class VsRematchButton extends StatelessWidget {
  const VsRematchButton({super.key, required this.asked, required this.offered, required this.opponentGone, required this.onPressed});

  /// 내가 이미 하자고 했다 / 상대가 하자고 했다 / 상대가 나갔다.
  final bool asked;
  final bool offered;
  final bool opponentGone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
      onPressed: asked || opponentGone ? null : onPressed,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(opponentGone
          ? '상대가 나갔어요'
          : asked
              ? '상대를 기다려요…'
              : offered
                  ? '한 판 더 (상대가 원해요)'
                  : '한 판 더'),
    );
  }
}

/// 대결 화면의 바탕: 배경 그라데이션 + 윗줄 + 세로/가로 배치.
///
/// 세로: 선수 칩 → 차례 안내 → 판 → [extras] → 아래 단추.
/// 가로: 왼쪽에 판을 크게, 오른쪽 칸([sideWidth])에 선수 칩 · 차례 안내 · [extras] · 아래 단추.
class VsGameScaffold extends StatelessWidget {
  const VsGameScaffold({
    super.key,
    required this.light,
    required this.dark,
    required this.topBar,
    required this.chips,
    required this.banner,
    required this.board,
    required this.bottom,
    this.extras = const [],
    this.landscapeExtras,
    this.sideWidth = 300,
    this.overlay,
  });

  /// 배경 그라데이션 (위 → 아래) 밝은 모드 / 어두운 모드.
  final List<Color> light;
  final List<Color> dark;
  final Widget topBar;
  final Widget chips;
  final Widget banner;
  final Widget board;
  final Widget bottom;

  /// 판 아래(세로) / 옆 칸(가로)에 더 놓을 것 (예: 숫자판, 나침반).
  final List<Widget> extras;

  /// 가로일 때만 다르게 놓을 것 (없으면 [extras]).
  final List<Widget>? landscapeExtras;
  final double sideWidth;

  /// 화면 전체 위에 겹칠 것 (예: 색종이). 손가락은 통과시켜야 한다.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight * 1.2;
        return Column(
          children: [
            topBar,
            Expanded(
              child: landscape
                  ? Row(
                      children: [
                        Expanded(child: board),
                        SizedBox(
                          width: sideWidth,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [chips, banner, const SizedBox(height: 12), ...(landscapeExtras ?? extras), bottom],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(children: [chips, banner, Expanded(child: board), ...extras, bottom]),
            ),
          ],
        );
      },
    );
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? dark : light),
        ),
        child: SafeArea(child: overlay == null ? body : Stack(children: [body, Positioned.fill(child: overlay!)])),
      ),
    );
  }
}

/// 같은 Wi‑Fi 대결에서 더 이어갈 수 없을 때의 안내 ("나가기" 하나).
Future<void> showVsNotice(BuildContext context, String title, String body) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wifi_off_rounded, size: 32),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(body, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('나가기'))],
      ),
    );

/// 진행 중인 Wi‑Fi 판에서 나가려 할 때 묻는다. 나가면 true.
Future<bool> confirmVsLeave(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('판에서 나갈까요?'),
      content: const Text('나가면 상대와의 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
      ],
    ),
  );
  return ok == true;
}

/// 상대가 기권했다는 안내. "한 판 더"를 고르면 true, "메뉴로"면 false.
Future<bool> showOpponentResigned(BuildContext context, {required bool canAgain}) async {
  final again = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.emoji_events_rounded, size: 32, color: Color(0xFFF2A900)),
      title: const Text('상대가 기권했어요', textAlign: TextAlign.center),
      content: const Text('이번 판은 내가 이긴 걸로 기록해 두었어요.', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
        if (canAgain) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
      ],
    ),
  );
  return again == true;
}

/// 판이 끝났을 때의 결과 창. "한 판 더"면 true, "메뉴로"면 false (바깥을 눌러 닫으면 null).
class VsResultDialog extends StatelessWidget {
  const VsResultDialog({super.key, required this.title, required this.body, this.art, this.canAgain = true});

  final String title;
  final String body;

  /// 이긴 쪽의 그림 (없으면 무승부 등).
  final Widget? art;

  /// false면 "한 판 더"가 없다 (Wi‑Fi 대결에서 상대가 나갔을 때).
  final bool canAgain;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?art,
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('메뉴로')),
        if (canAgain) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('한 판 더')),
      ],
    );
  }
}

/// 규칙 설명 창: 항목들 + "게임 방법 자세히"(튜토리얼) + "알겠어요".
Future<void> showVsRules(BuildContext context, {required String title, required List<String> lines, required VoidCallback openTutorial}) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Text('•  '), Expanded(child: Text(t, style: const TextStyle(height: 1.4)))],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in lines) line(t)]),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            openTutorial();
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
