import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/dot_assess.dart';
import '../core/dot_convert.dart';
import '../core/dot_enhance.dart';
import '../core/dot_levels.dart';
import '../data/dot_custom_store.dart';
import '../dotcannon_entry.dart';
import 'dot_menu_screen.dart';
import 'dot_painter.dart';

/// 갤러리 사진을 도트 그림으로 바꾸고, 난이도를 매겨 보여 준 뒤 시작하는 화면.
class DotCreateScreen extends StatefulWidget {
  const DotCreateScreen({super.key, required this.bytes});

  /// 고른 사진 파일의 내용.
  final Uint8List bytes;

  @override
  State<DotCreateScreen> createState() => _DotCreateScreenState();
}

class _DotCreateScreenState extends State<DotCreateScreen> {
  static const List<int> _sizes = [16, 24, 32, 48, 64];
  static const List<String> _sizeNames = ['작게', '보통', '크게', '더 크게', '최대'];
  static const List<int> _capacities = [5, 4, 3];
  static const List<String> _capacityNames = ['쉽게', '보통', '어렵게'];

  int _sizeIndex = 1; // 24칸 (긴 쪽)
  int _colors = 6;
  bool _removeBg = false;
  bool _enhance = true;
  int _capIndex = 1;
  late final TextEditingController _name;

  int? _imgW, _imgH;
  final Map<int, (Uint8List, int, int)> _raw = {}; // 크기별로 줄여 읽은 사진 (RGBA, 가로, 세로)
  DotArt? _art;
  DotAssessment? _assess;
  bool _failed = false;
  bool _assessing = false;
  bool _starting = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _name = TextEditingController(text: '내 그림 ${now.month}.${now.day}');
    _rebuild();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 사진을 [sw]×[sh]로 줄여 RGBA로 읽는다.
  Future<(Uint8List, int, int)> _decode(int sw, int sh) async {
    final codec = await ui.instantiateImageCodec(widget.bytes, targetWidth: sw, targetHeight: sh);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final out = (data!.buffer.asUint8List(), frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return out;
  }

  Future<void> _rebuild() async {
    final req = ++_request;
    setState(() {
      _assessing = true;
      _assess = null;
    });
    try {
      if (_imgW == null) {
        final codec = await ui.instantiateImageCodec(widget.bytes);
        final frame = await codec.getNextFrame();
        _imgW = frame.image.width;
        _imgH = frame.image.height;
        frame.image.dispose();
        codec.dispose();
      }
      final long = _sizes[_sizeIndex];
      final (dw, dh) = dotSizeFor(_imgW!, _imgH!, long);
      var raw = _raw[long];
      if (raw == null) {
        raw = await _decode(dw * 4, dh * 4);
        _raw[long] = raw;
      }
      if (!mounted || req != _request) return;
      final plain = boxDownsample(raw.$1, raw.$2, raw.$3, dw, dh);
      final cells = _enhance ? enhanceCells(plain, dw, dh) : plain;
      final art = quantizeCells(cells, dw, dh, colors: _colors, removeBackground: _removeBg);
      if (art.colors.isEmpty || art.pixelCount < 6) {
        setState(() {
          _art = art;
          _failed = true;
          _assessing = false;
        });
        return;
      }
      setState(() {
        _art = art;
        _failed = false;
      });
      final map = await compute(assessArtMap, {
        'px': art.pixels,
        'w': art.width,
        'h': art.height,
        'colors': art.colors.length,
        'cap': _capacities[_capIndex],
      });
      if (!mounted || req != _request) return;
      setState(() {
        _assess = DotAssessment.fromMap(map);
        _assessing = false;
      });
    } catch (_) {
      if (!mounted || req != _request) return;
      setState(() {
        _failed = true;
        _assessing = false;
      });
    }
  }

  DotLevel? _level() {
    final art = _art, a = _assess;
    if (art == null || a == null) return null;
    final name = _name.text.trim().isEmpty ? '내 그림' : _name.text.trim();
    return DotLevel(
      id: DotCustomStore.newId(),
      name: name,
      colors: art.colors,
      pixels: art.pixels,
      width: art.width,
      height: art.height,
      columns: a.columns,
      ammoLo: a.ammoLo,
      ammoHi: a.ammoHi,
      seed: a.seed,
      capacity: a.capacity,
      custom: true,
      difficulty: a.difficulty,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _start() async {
    final level = _level();
    if (level == null || _starting) return;
    setState(() => _starting = true);
    await DotCustomStore.save(level);
    if (!mounted) return;
    await startDotCannon(context, level, replace: true, askIfSaved: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final art = _art;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 사진으로 만들기', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                // 변환 결과
                AspectRatio(
                  aspectRatio: 1.25,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F1E3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF8C5A34), width: 6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: art == null
                          ? const Center(child: CircularProgressIndicator())
                          : _failed
                              ? const Center(
                                  child: Text('이 사진은 도트로 바꾸기 어려워요.\n다른 사진이나 다른 설정으로 해 보세요.', textAlign: TextAlign.center),
                                )
                              : CustomPaint(
                                  key: const ValueKey('dot-preview'),
                                  painter: DotArtPainter(art.pixels, art.width, art.height, art.colors),
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _assessmentCard(scheme),
                const SizedBox(height: 18),
                TextField(
                  controller: _name,
                  maxLength: 14,
                  decoration: const InputDecoration(labelText: '그림 이름', border: OutlineInputBorder(), counterText: ''),
                ),
                const SizedBox(height: 14),
                _label('도트 크기 (긴 쪽 칸 수)'),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var i = 0; i < _sizes.length; i++)
                      ButtonSegment(
                        value: i,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_sizes[i]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(_sizeNames[i], style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                  selected: {_sizeIndex},
                  onSelectionChanged: (s) {
                    setState(() => _sizeIndex = s.first);
                    _rebuild();
                  },
                ),
                if (_sizes[_sizeIndex] >= 48)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '큰 그림은 풀리는 배치를 찾느라 몇 초에서 몇십 초 걸려요. 도트가 많아서 한 판도 오래 걸려요.',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                const SizedBox(height: 14),
                _label('색 수: 최대 $_colors가지 (비슷한 색은 하나로 합쳐요)'),
                Slider(
                  value: _colors.toDouble(),
                  min: 2,
                  max: 12,
                  divisions: 10,
                  label: '$_colors',
                  onChanged: (v) => setState(() => _colors = v.round()),
                  onChangeEnd: (_) => _rebuild(),
                ),
                SwitchListTile(
                  key: const ValueKey('dot-enhance'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('모양 또렷하게'),
                  subtitle: const Text('대비와 색을 키우고 윤곽을 살려요 (색이 조금 달라져요)'),
                  value: _enhance,
                  onChanged: (v) {
                    setState(() => _enhance = v);
                    _rebuild();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('배경색 지우기'),
                  subtitle: const Text('가장자리에서 이어진 배경을 빈 칸으로 만들어요'),
                  value: _removeBg,
                  onChanged: (v) {
                    setState(() => _removeBg = v);
                    _rebuild();
                  },
                ),
                const SizedBox(height: 6),
                _label('벨트 자리 (대포를 올려 둘 수 있는 수)'),
                SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < _capacities.length; i++)
                      ButtonSegment(value: i, label: Text('${_capacityNames[i]} ${_capacities[i]}')),
                  ],
                  selected: {_capIndex},
                  onSelectionChanged: (s) {
                    setState(() => _capIndex = s.first);
                    _rebuild();
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey('dot-start-custom'),
                  onPressed: (_assess == null || _failed || _starting) ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('이 그림으로 시작'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(
                  '시작하면 "내가 만든 그림"에 저장돼요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      );

  Widget _assessmentCard(ColorScheme scheme) {
    final art = _art;
    final a = _assess;
    if (_failed || art == null) return const SizedBox.shrink();
    if (a == null || _assessing) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 12),
            Text('난이도를 재는 중이에요…'),
          ],
        ),
      );
    }
    final color = dotDifficultyColors[a.difficulty];
    final cannons = DotLevel(
      id: 'tmp',
      name: '',
      colors: art.colors,
      pixels: art.pixels,
      width: art.width,
      height: art.height,
      columns: a.columns,
      ammoLo: a.ammoLo,
      ammoHi: a.ammoHi,
      seed: a.seed,
      capacity: a.capacity,
    ).newGame().waiting;
    return Container(
      key: const ValueKey('dot-assessment'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('난이도 ', style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.7))),
              Text(dotDifficultyNames[a.difficulty], style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color)),
              const Spacer(),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.circle, size: 12, color: i <= a.difficulty ? color : color.withValues(alpha: 0.2)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '도트 ${art.pixelCount}개 · 색 ${art.colors.length}가지 · 대포 $cannons대 · 벨트 ${a.capacity}자리',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 2),
          Text(
            a.capacity != _capacities[_capIndex]
                ? '벨트 ${_capacities[_capIndex]}자리로는 풀리는 배치를 못 찾아서 ${a.capacity}자리로 했어요. '
                    '아무렇게나 올리면 ${(a.randomWinRate * 100).round()}%만 깰 수 있어요.'
                : '아무렇게나 대포를 올리면 ${(a.randomWinRate * 100).round()}%만 깰 수 있어요. 풀리는 배치예요.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
