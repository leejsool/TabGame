import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/settings_scope.dart';
import '../audio/rhythm_audio.dart';
import '../data/rhythm_storage.dart';

const _ink = Color(0xFF1A1523);
const _gold = Color(0xFFFFD21F);

/// 박자 보정: 똑딱 소리 4번을 "4, 3, 2, 1"로 세며 듣고, 이어지는 10번에 맞춰 탭하면
/// 기기의 소리·터치 지연을 재서 저장한다.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> with SingleTickerProviderStateMixin {
  static const _interval = 0.6; // 초
  static const _countIn = 4; // 듣기만 하는 박자
  static const _count = 10; // 측정하는 박자
  static const _firstAt = 1.4; // 시작을 누르고 첫 소리까지

  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _sw = Stopwatch();
  RhythmSfx? _sfx;
  bool _running = false;
  bool _done = false;
  int _played = 0; // 지금까지 난 소리 수 (듣기 + 측정)
  final List<double> _errors = [];
  int _savedMs = 0;
  int? _resultMs;
  double _flash = 0;

  double get _now => _sw.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    RhythmStorage.loadOffsetMs().then((v) {
      if (mounted) setState(() => _savedMs = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sfx != null) return;
    final sfx = SettingsScope.of(context).sound ? PoolSfx.shared : const SilentSfx();
    _sfx = sfx;
    sfx.load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sfx?.dispose();
    super.dispose();
  }

  void _start() {
    // 첫 소리(1.4초 뒤)가 늦지 않도록 오디오 출력을 미리 깨운다
    _sfx?.warmUp();
    _errors.clear();
    _played = 0;
    _done = false;
    _resultMs = null;
    _sw
      ..reset()
      ..start();
    _running = true;
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _onTick(Duration _) {
    if (!_running) return;
    final t = _now;
    while (_played < _countIn + _count && t >= _firstAt + _played * _interval) {
      _sfx?.play(_played % 4 == 0 ? Sfx.tickHi : Sfx.tick);
      _flash = 1;
      _played++;
    }
    _flash = (_flash - 0.08).clamp(0.0, 1.0);
    if (_played >= _countIn + _count && t > _firstAt + (_countIn + _count - 1) * _interval + 0.5) _finish();
    setState(() {});
  }

  void _tap() {
    if (!_running) return;
    final t = _now;
    // 듣기 박자는 건너뛰고, 측정 박자 중 가장 가까운 것과의 차이
    final k = ((t - _firstAt) / _interval).round() - _countIn;
    if (k < 0 || k >= _count) return;
    final err = t - (_firstAt + (_countIn + k) * _interval);
    if (err.abs() > 0.3) return;
    if (_errors.length >= _count) return;
    _errors.add(err);
    setState(() {});
  }

  void _finish() {
    _running = false;
    _sw.stop();
    _done = true;
    if (_errors.length >= 4) {
      final s = [..._errors]..sort();
      final median = s[s.length ~/ 2];
      _resultMs = (median * 1000).round().clamp(-300, 300);
    }
  }

  Future<void> _save() async {
    final ms = _resultMs;
    if (ms == null) return;
    await RhythmStorage.saveOffsetMs(ms);
    if (!mounted) return;
    setState(() => _savedMs = ms);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보정값을 저장했어요')));
  }

  Future<void> _adjust(int delta) async {
    final v = (_savedMs + delta).clamp(-300, 300);
    await RhythmStorage.saveOffsetMs(v);
    if (mounted) setState(() => _savedMs = v);
  }

  /// 가운데 원에 보여 줄 글자: 준비 → 4 3 2 1(듣기 카운트다운) → 탭!(측정)
  (String, String) get _bubble {
    if (_done) return ('끝!', '');
    if (!_running) return ('준비', '시작을 누르세요');
    final t = _now;
    if (t < _firstAt - 0.05) return ('준비', '잠시 뒤 소리가 나요');
    // 듣기 박자는 남은 박 수를 거꾸로 센다: 첫 소리가 4, 마지막이 1 — 1 다음 박자부터 탭하면 된다
    if (_played <= _countIn) return ('${_countIn + 1 - _played.clamp(1, _countIn)}', '들어 보세요 (탭하지 마세요)');
    return ('탭!', '소리에 맞춰 탭하세요');
  }

  @override
  Widget build(BuildContext context) {
    final (big, small) = _bubble;
    final measuring = _running && _played > _countIn;
    return Scaffold(
      appBar: AppBar(title: const Text('박자 보정', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(top: false, child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _tap(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '기기마다 소리가 나오는 속도와 화면이 반응하는 속도가 조금씩 달라요.\n"똑딱" 소리를 4, 3, 2, 1로 세며 듣고, 그다음부터 이어지는 10번에 맞춰 화면을 탭하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(measuring ? const Color(0xFFFFE9A8) : const Color(0xFFE6F0FF), _gold, _flash),
                      border: Border.all(color: _ink, width: 5),
                    ),
                    alignment: Alignment.center,
                    child: Text(big, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _ink)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(height: 22, child: Text(small, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _count; i++)
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _errors.length ? const Color(0xFF3FA06A) : (i < _played - _countIn ? const Color(0xFFD9CDB5) : const Color(0xFFEFE6D2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_done)
                    Text(
                      _resultMs == null
                          ? '탭이 너무 적었어요. 다시 해 볼까요?'
                          : '평균 ${_resultMs! >= 0 ? '+' : ''}$_resultMs ms ${_resultMs!.abs() < 15 ? '· 딱 좋아요!' : _resultMs! > 0 ? '· 조금 늦게 쳤어요' : '· 조금 일찍 쳤어요'}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: _running ? null : _start,
                        child: Padding(padding: const EdgeInsets.all(8), child: Text(_done ? '다시 재기' : '시작', style: const TextStyle(fontWeight: FontWeight.w800))),
                      ),
                      if (_done && _resultMs != null)
                        FilledButton.tonal(
                          onPressed: _save,
                          child: const Padding(padding: EdgeInsets.all(8), child: Text('이 값으로 저장', style: TextStyle(fontWeight: FontWeight.w800))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.outlined(onPressed: () => _adjust(-10), icon: const Icon(Icons.remove_rounded)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          children: [
                            const Text('저장된 보정값', style: TextStyle(fontSize: 12)),
                            Text('${_savedMs >= 0 ? '+' : ''}$_savedMs ms', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      IconButton.outlined(onPressed: () => _adjust(10), icon: const Icon(Icons.add_rounded)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}
