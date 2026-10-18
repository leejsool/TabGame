import 'package:flutter/material.dart';

/// 게임 화면 아래 도구 줄의 단추 하나 (아이콘 + 짧은 이름). [Row] 안에서 남는 폭을 나눠 갖는다.
/// [onTap]이 없으면 흐리게 보이고 눌리지 않는다. [highlight]면 강조색 (예: 힌트가 켜져 있을 때).
class GameBarButton extends StatelessWidget {
  const GameBarButton({super.key, required this.icon, required this.label, required this.onTap, this.highlight = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = highlight ? scheme.primary : scheme.onSurface.withValues(alpha: 0.78);
    final color = onTap == null ? base.withValues(alpha: 0.3) : base;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 3),
              Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 게임 첫 화면(메뉴·대결 설정)의 "이어하기" 카드. [detail]은 이어할 판을 한 줄로 설명한다 (예: "쉬움 · 03:12 · 40% 완료").
class ResumeCard extends StatelessWidget {
  const ResumeCard({super.key, required this.detail, required this.onTap, this.compact = false});

  final String detail;
  final VoidCallback onTap;

  /// 대결 설정 화면처럼 다른 고르기 칸들 사이에 들어갈 때의 조금 작은 모양.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: compact ? const EdgeInsets.fromLTRB(18, 14, 14, 14) : const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: compact ? 40 : 44, color: scheme.primary),
              SizedBox(width: compact ? 14 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이어하기', style: TextStyle(fontSize: compact ? 18 : 20, fontWeight: compact ? FontWeight.w900 : FontWeight.w800)),
                    SizedBox(height: compact ? 2 : 4),
                    Text(detail, style: compact ? const TextStyle(fontSize: 13.5) : null),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
    // (메뉴 화면의 카드들과 같은 바깥 여백)
    return compact ? card : Padding(padding: const EdgeInsets.all(4), child: card);
  }
}

/// 혼자 하기 메뉴 칸의 최대 폭: 세로는 640, 가로로 넓은 태블릿은 960 (난이도 카드를 2열로 놓을 수 있게).
double menuMaxWidth(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.landscape ? 960 : 640;

/// 난이도 카드 같은 것을 폭이 넉넉하면 2열, 좁으면 1열로 쌓는다 (카드 사이 간격 12).
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 700) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ]);
      }
      final w = (box.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in children) SizedBox(width: w, child: c)]);
    });
  }
}
