import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_discovery.dart';
import '../../../records/records_screen.dart';
import '../core/prophecy_rules.dart';
import 'prophecy_board.dart';
import 'prophecy_screen.dart';
import 'prophecy_setup_screen.dart';

/// 방을 만드는 쪽이 "내 쪽"을 상대가 들어올 때 무작위로 정하겠다고 할 때의 값.
const int kRandomSide = -1;

const String _game = 'prophecy';

/// 같은 Wi‑Fi로 함께 하기의 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 판을 보며
/// 차례로 수를 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [ProphecyScreen]의 Wi‑Fi 모드)
class ProphecyWifiScreen extends StatelessWidget {
  const ProphecyWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('예언 · 같은 Wi‑Fi로 함께', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: _game),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kProphColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kProphColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_rounded, size: 48, color: kProphColor),
                      const SizedBox(height: 10),
                      const Text('같은 Wi‑Fi에 연결된 두 기기가 있으면\n서로 마주 보지 않아도 겨룰 수 있어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
                      const SizedBox(height: 8),
                      Text(
                        '한 기기에서 방을 만들고, 다른 기기에서 그 방을 찾아 들어오세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProphecySetupScreen(mode: PlayMode.wifi))),
                  icon: const Icon(Icons.add_home_work_rounded),
                  label: const Text('방 만들기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProphecyJoinScreen())),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('방 찾기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '공용 Wi‑Fi나 손님용 Wi‑Fi 중에는 기기끼리의 연결을 막아 둔 곳이 있어요. 방이 보이지 않으면 방을 만든 기기의 주소를 직접 입력해 보세요.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class ProphecyHostScreen extends StatefulWidget {
  const ProphecyHostScreen({
    super.key,
    required this.rows,
    required this.cols,
    required this.hostSide,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  final int rows, cols;

  /// 내가 맡을 쪽 (0 = 먼저, 1 = 나중, [kRandomSide] = 상대가 들어올 때 무작위).
  final int hostSide;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  State<ProphecyHostScreen> createState() => _ProphecyHostScreenState();
}

class _ProphecyHostScreenState extends State<ProphecyHostScreen> {
  LanHost? _host;
  StreamSubscription<LanConnection>? _sub;
  List<String> _addresses = const [];
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final host = await LanHost.open(
        game: _game,
        info: {'rows': widget.rows, 'cols': widget.cols, 'hostSide': widget.hostSide},
        gamePort: widget.gamePort,
        discoveryPort: widget.discoveryPort,
      );
      if (!mounted) {
        await host.close();
        return;
      }
      _host = host;
      _sub = host.guests.listen(_onGuest);
      final addresses = await localLanAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (_) {
      if (mounted) setState(() => _error = '방을 열 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  Future<void> _onGuest(LanConnection conn) async {
    if (_starting) {
      conn.close();
      return;
    }
    _starting = true;
    final mySide = widget.hostSide == kRandomSide ? Random().nextInt(2) : widget.hostSide;
    conn.send({'t': 'start', 'rows': widget.rows, 'cols': widget.cols, 'side': 1 - mySide});
    await _host?.close(); // 방은 닫는다 (이미 이어진 연결은 그대로)
    _host = null;
    if (!mounted) {
      conn.close();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProphecyScreen(mode: PlayMode.wifi, rows: widget.rows, cols: widget.cols, humanSide: mySide, link: conn),
      ),
    );
    // 게임에서 나오면 방도 끝난 것이니 방 설정 화면으로 돌아간다.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
    super.dispose();
  }

  String get _sideText => switch (widget.hostSide) {
        0 => '내가 먼저 쓰기',
        1 => '내가 나중에 쓰기',
        _ => '먼저/나중은 상대가 들어오면 무작위로',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('상대를 기다리는 중', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null) ...[
                  Icon(Icons.wifi_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _open, child: const Text('다시 시도')),
                ] else ...[
                  const Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5))),
                  const SizedBox(height: 18),
                  const Text('방이 열렸어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '다른 기기에서 예언 → "같은 Wi‑Fi로 함께" → "방 찾기"를 눌러\n이 방에 들어오면 바로 시작해요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 20),
                  _InfoCard(lines: ['표 ${widget.rows}×${widget.cols}', _sideText]),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: '방이 안 보이면, 이 주소를 상대 기기에 직접 입력하세요',
                    lines: [
                      if (_addresses.isEmpty) 'Wi‑Fi 주소를 찾지 못했어요. Wi‑Fi에 연결되어 있는지 확인해 주세요.',
                      for (final a in _addresses) _host != null && _host!.port != kLanGamePort ? '$a:${_host!.port}' : a,
                    ],
                    big: _addresses.isNotEmpty,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, required this.lines, this.big = false});

  final String? title;
  final List<String> lines;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65))),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(l, textAlign: TextAlign.center, style: TextStyle(fontSize: big ? 22 : 15, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class ProphecyJoinScreen extends StatefulWidget {
  const ProphecyJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  State<ProphecyJoinScreen> createState() => _ProphecyJoinScreenState();
}

class _ProphecyJoinScreenState extends State<ProphecyJoinScreen> {
  LanFinder? _finder;
  StreamSubscription<List<LanRoom>>? _sub;
  List<LanRoom> _rooms = const [];
  bool _connecting = false;
  String? _message;
  final TextEditingController _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startFinder();
  }

  Future<void> _startFinder() async {
    try {
      final finder = await LanFinder.start(game: _game, discoveryPort: widget.discoveryPort, extraTargets: widget.extraTargets);
      if (!mounted) {
        finder.close();
        return;
      }
      _finder = finder;
      _sub = finder.rooms.listen((r) {
        if (mounted) setState(() => _rooms = r);
      });
    } catch (_) {
      if (mounted) setState(() => _message = '방을 찾을 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  void _stopFinder() {
    _sub?.cancel();
    _finder?.close();
    _sub = null;
    _finder = null;
    _rooms = const [];
  }

  @override
  void dispose() {
    _stopFinder();
    _address.dispose();
    super.dispose();
  }

  Future<void> _join(String host, int port) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _message = null;
    });
    LanConnection? conn;
    var started = false;
    try {
      conn = await LanConnection.connect(host, port);
      conn.send(const {'t': 'hello', 'game': _game});
      final m = await conn.messages.firstWhere((m) => m['t'] == 'start' || m['t'] == 'busy').timeout(const Duration(seconds: 8));
      if (m['t'] == 'busy') {
        conn.close();
        if (mounted) setState(() => _message = '이미 다른 기기가 이 방에 들어와 있어요.');
        return;
      }
      final rows = m['rows'], cols = m['cols'], side = m['side'];
      if (rows is! int || cols is! int || side is! int || rows < kMinSide || rows > kMaxSide || cols < kMinSide || cols > kMaxSide || (side != 0 && side != 1)) {
        throw const FormatException('start');
      }
      if (!mounted) {
        conn.close();
        return;
      }
      started = true;
      _stopFinder();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProphecyScreen(mode: PlayMode.wifi, rows: rows, cols: cols, humanSide: side, link: conn),
        ),
      );
      if (mounted) _startFinder();
    } catch (_) {
      conn?.close();
      if (mounted && !started) setState(() => _message = '방에 들어갈 수 없어요. 방이 아직 열려 있는지, 같은 Wi‑Fi인지 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// "192.168.0.12" 또는 "192.168.0.12:45822".
  void _joinTyped() {
    final text = _address.text.trim();
    if (text.isEmpty) return;
    final parts = text.split(':');
    final port = parts.length > 1 ? int.tryParse(parts[1]) : kLanGamePort;
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _message = '주소를 다시 확인해 주세요. (예: 192.168.0.12)');
      return;
    }
    _join(parts[0], port);
  }

  String _roomText(LanRoom r) {
    final side = switch (r.info['hostSide']) {
      0 => '방 만든 사람이 먼저 쓰기',
      1 => '방 만든 사람이 나중에 쓰기',
      _ => '먼저/나중은 들어가면 정해져요',
    };
    return '$side · ${r.address}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('방 찾기', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_message!, style: const TextStyle(fontSize: 14, height: 1.35))),
                      ],
                    ),
                  ),
                Text('열려 있는 방', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_rooms.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
                        const SizedBox(height: 14),
                        const Text('같은 Wi‑Fi의 방을 찾는 중…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '다른 기기에서 "방 만들기 → 방 열기"를 먼저 눌러 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in _rooms)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: kProphColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.wifi_rounded, color: kProphColor),
                        ),
                        title: Text('표 ${r.info['rows']}×${r.info['cols']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(_roomText(r), style: const TextStyle(fontSize: 12.5)),
                        trailing: FilledButton(onPressed: _connecting ? null : () => _join(r.address, r.port), child: const Text('들어가기')),
                      ),
                    ),
                const SizedBox(height: 24),
                Text('주소로 들어가기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '방이 위에 안 보이면, 방을 만든 기기 화면에 나온 주소를 입력하세요.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _address,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _joinTyped(),
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '주소', hintText: '192.168.0.12', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _connecting ? null : _joinTyped, child: const Text('들어가기')),
                  ],
                ),
                if (_connecting) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
