import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/record_widgets.dart';
import '../core/jigsaw_geometry.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';

/// 고른 그림으로 퍼즐을 만들기 전 설정: 조각 수 + 밑그림.
class JigsawSetupScreen extends StatefulWidget {
  const JigsawSetupScreen({super.key, required this.pick, this.initialTarget = 24});

  final PickedImage pick;

  /// 처음에 골라져 있을 조각 수 (보관함의 퍼즐은 지난번에 고른 값).
  final int initialTarget;

  @override
  State<JigsawSetupScreen> createState() => _JigsawSetupScreenState();
}

class _JigsawSetupScreenState extends State<JigsawSetupScreen> {
  late int _target = kPieceChoices.any((c) => c.$1 == widget.initialTarget) ? widget.initialTarget : 24;
  bool _ghost = true;
  final Map<int, int?> _best = {};

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _start() async {
    // 같은 그림으로 이어하던 판이 있으면 새로 시작하기 전에 물어본다
    final saved = await JigsawStorage.entryFor(widget.pick.source);
    if (!mounted) return;
    if (saved != null && saved.inProgress) {
      final ok = await confirmOverwrite(context, gameName: '이 그림의 퍼즐');
      if (!ok || !mounted) return;
    }
    await startJigsawGame(context, widget.pick, pieceTarget: _target, ghost: _ghost);
  }

  Future<void> _loadBest() async {
    for (final (n, _) in kPieceChoices) {
      _best[n] = await JigsawStorage.bestSeconds(n);
    }
    if (mounted) setState(() {});
  }

  /// 실제로 나뉠 조각 수 (그림 비율에 맞춰 조금 달라질 수 있다).
  int _actualCount(int target) {
    final img = widget.pick.image;
    final (r, c) = JigsawGeometry.gridFor(target, img.width / img.height);
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = widget.pick.image;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: img.width / img.height,
        child: RawImage(image: img, fit: BoxFit.cover),
      ),
    );
    final options = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('조각 수',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final (n, name) in kPieceChoices) ...[
          _ChoiceTile(
            title: '$name · ${_actualCount(n)}조각',
            subtitle: _best[n] == null ? '아직 기록이 없어요' : '최고 ${formatTime(_best[n]!)}',
            selected: _target == n,
            onTap: () => setState(() => _target = n),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _ghost,
          onChanged: (v) => setState(() => _ghost = v),
          title: const Text('밑그림 보이기'),
          subtitle: const Text('판 위에 완성 그림이 희미하게 보여요. 어려운 도전은 꺼보세요.'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.extension_rounded),
          label: const Text('퍼즐 시작'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '조각은 끌어서 맞춰요. 손가락 두 개로 확대하고, 한 손가락으로 화면을 밀 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('퍼즐 만들기', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > 760;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1000 : 560),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: preview),
                          const SizedBox(width: 28),
                          Expanded(flex: 4, child: options),
                        ],
                      )
                    : Column(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.38),
                            child: preview,
                          ),
                          const SizedBox(height: 20),
                          options,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      elevation: selected ? 0 : 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(subtitle, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
