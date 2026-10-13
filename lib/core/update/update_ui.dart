import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../settings.dart';
import 'update_service.dart';

/// 자동 확인은 이 시간이 지난 뒤에만 다시 한다.
const Duration kAutoCheckInterval = Duration(hours: 6);

/// 앱을 켤 때 부르는 자동 확인. 설정이 꺼져 있거나 최근에 확인했으면 아무것도 안 한다.
/// 새 버전이 있을 때만 대화상자를 띄우고, 인터넷이 안 되는 등의 실패는 조용히 넘어간다.
Future<void> autoCheckForUpdate(BuildContext context, Settings settings) async {
  if (!updatesSupported || !settings.autoUpdateCheck) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - settings.lastUpdateCheckMs < kAutoCheckInterval.inMilliseconds) return;
  await checkForUpdate(context, settings, manual: false);
}

/// 새 버전을 확인하고, 있으면 내려받아 설치할지 묻는다.
/// [manual]이면 "최신 버전이에요", "확인하지 못했어요" 같은 결과도 알려준다.
Future<void> checkForUpdate(
  BuildContext context,
  Settings settings, {
  required bool manual,
  UpdateService? service,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger?.showSnackBar(SnackBar(content: Text(text)));

  if (!updatesSupported) {
    if (manual) say('업데이트는 안드로이드 앱에서만 쓸 수 있어요');
    return;
  }
  final svc = service ?? UpdateService();
  UpdateInfo? update;
  try {
    update = await svc.checkForUpdate();
  } catch (_) {
    if (manual) say('업데이트를 확인하지 못했어요. 인터넷 연결을 확인해 주세요');
    return;
  }
  settings.lastUpdateCheckMs = DateTime.now().millisecondsSinceEpoch;
  if (!context.mounted) return;
  if (update == null) {
    if (manual) {
      final current = await svc.currentVersion().catchError((_) => null);
      say(current == null ? '최신 버전이에요' : '최신 버전이에요 (v$current)');
    }
    return;
  }
  final go = await showDialog<bool>(
    context: context,
    builder: (_) => _UpdateAvailableDialog(info: update!),
  );
  if (go != true || !context.mounted) return;
  await downloadAndInstall(context, update, service: svc);
}

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)}MB';

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('새 버전 v${info.version}이 나왔어요'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.notes.isNotEmpty) Text(info.notes, style: const TextStyle(height: 1.4)),
            if (info.notes.isNotEmpty) const SizedBox(height: 12),
            Text(
              info.size > 0 ? '내려받는 크기: ${_mb(info.size)}' : '지금 내려받아 바로 설치할 수 있어요',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('나중에')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('업데이트')),
      ],
    );
  }
}

/// [info]를 내려받는 진행 화면을 띄우고, 다 받으면 설치 화면을 연다.
Future<void> downloadAndInstall(BuildContext context, UpdateInfo info, {UpdateService? service}) async {
  final svc = service ?? UpdateService();
  final dir = Directory('${(await getTemporaryDirectory()).path}/update');
  if (!context.mounted) return;
  final apk = await showDialog<File>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(info: info, service: svc, dir: dir),
  );
  if (apk == null || !context.mounted) return;
  await _install(context, svc, apk);
}

/// 설치 화면을 연다. '설치 허용'이 꺼져 있으면 설정 화면으로 보내고, 켠 뒤 다시 누를 수 있게 한다.
Future<void> _install(BuildContext context, UpdateService svc, File apk) async {
  final InstallResult r;
  try {
    r = await svc.install(apk);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('설치 화면을 열지 못했어요')));
    }
    return;
  }
  if (r != InstallResult.needPermission || !context.mounted) return;
  final again = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('설치를 허용해 주세요'),
      content: const Text('열린 설정 화면에서 "이 출처 허용"을 켠 다음, 이 앱으로 돌아와서 "설치"를 눌러 주세요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('설치')),
      ],
    ),
  );
  if (again == true && context.mounted) await _install(context, svc, apk);
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.info, required this.service, required this.dir});

  final UpdateInfo info;
  final UpdateService service;
  final Directory dir;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final _cancel = UpdateCancelToken();
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cancel.cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final file = await widget.service.download(
        widget.info,
        widget.dir,
        cancel: _cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.pop(context, file);
    } on UpdateCancelled {
      // 취소 버튼으로 이미 닫혔다
    } catch (e) {
      if (mounted) setState(() => _error = e is HttpException ? e.message : '내려받지 못했어요. 인터넷 연결을 확인해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.info.size;
    return AlertDialog(
      title: Text(_error == null ? 'v${widget.info.version} 내려받는 중' : '내려받지 못했어요'),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 10),
                Text(
                  total > 0
                      ? '${(_progress * 100).round()}%  (${_mb((total * _progress).round())} / ${_mb(total)})'
                      : '${(_progress * 100).round()}%',
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () {
            _cancel.cancelled = true;
            Navigator.pop(context);
          },
          child: Text(_error == null ? '취소' : '닫기'),
        ),
        if (_error != null) FilledButton(onPressed: _start, child: const Text('다시 시도')),
      ],
    );
  }
}
