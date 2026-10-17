import 'package:flutter/material.dart';

import 'game_save.dart';

/// 설정 화면 없이 바로 시작하는 대결(한 기기로 둘이서)의 첫 화면.
///
/// 이어하던 판이 없으면 곧바로 [fresh]를 보여 주고, 있으면 "이어하기 / 새로 시작" 중 고르게 한다.
/// (새로 시작하면 이어하던 판은 사라진다고 먼저 알려 준다.)
class ResumeGate extends StatefulWidget {
  const ResumeGate({
    super.key,
    required this.gameId,
    required this.gameName,
    required this.fresh,
    required this.resumeBuilder,
    required this.describe,
  });

  final String gameId;

  /// 안내 글에 쓰는 게임 이름.
  final String gameName;

  /// 새 판 화면.
  final WidgetBuilder fresh;

  /// 저장된 판으로 만든 화면. 저장된 내용이 맞지 않아 되살릴 수 없으면 null.
  final Widget? Function(Map<String, dynamic> saved) resumeBuilder;

  /// 저장된 판을 한 줄로 설명한다.
  final String Function(Map<String, dynamic> saved) describe;

  @override
  State<ResumeGate> createState() => _ResumeGateState();
}

class _ResumeGateState extends State<ResumeGate> {
  bool _loaded = false;
  Map<String, dynamic>? _saved;
  Widget? _screen; // 정해진 화면 (새 판 / 이어하기)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await GameSave.load(widget.gameId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _saved = saved;
      if (saved == null) _screen = widget.fresh(context);
    });
  }

  void _resume() {
    final screen = widget.resumeBuilder(_saved!);
    if (screen == null) {
      _startFresh(); // (되살릴 수 없는 저장은 버린다)
      return;
    }
    setState(() => _screen = screen);
  }

  Future<void> _startFresh() async {
    await GameSave.clear(widget.gameId);
    if (!mounted) return;
    setState(() => _screen = widget.fresh(context));
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    if (screen != null) return screen;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          key: const ValueKey('gate-resume'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: _resume,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                            child: Row(
                              children: [
                                Icon(Icons.play_circle_fill_rounded, size: 40, color: scheme.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('이어하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 2),
                                      Text(widget.describe(_saved!), style: const TextStyle(fontSize: 13.5)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const ValueKey('gate-fresh'),
                        onPressed: _startFresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('새로 시작'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '새로 시작하면 이어하던 ${widget.gameName} 판은 사라져요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
