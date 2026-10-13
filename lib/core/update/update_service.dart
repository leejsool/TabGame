import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 앱이 업데이트를 찾아볼 GitHub 저장소.
const String kUpdateRepo = 'leejsool/TabGame';

/// 'v1.2.3' 또는 '1.2.3+4' 같은 버전. 큰 번호부터 비교한다.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major, minor, patch;

  /// 읽을 수 없는 글자면 null.
  static AppVersion? tryParse(String? text) {
    final m = RegExp(r'^\s*[vV]?(\d+)\.(\d+)\.(\d+)').firstMatch(text ?? '');
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// GitHub 릴리즈 하나: 새 버전 번호, 설명, 내려받을 APK.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkName,
    required this.size,
    this.sha256,
  });

  final AppVersion version;
  final String notes;
  final Uri apkUrl;
  final String apkName;

  /// 바이트 수 (모르면 0).
  final int size;

  /// APK의 SHA-256 (소문자 16진수). GitHub가 알려줄 때만 있다.
  final String? sha256;

  /// GitHub 릴리즈 API 응답에서 만든다. 쓸 수 있는 APK가 없으면 null.
  static UpdateInfo? fromRelease(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final version = AppVersion.tryParse(json['tag_name'] as String?);
    if (version == null) return null;
    final assets = json['assets'];
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is! Map) continue;
      final name = a['name'];
      final url = a['browser_download_url'];
      if (name is! String || url is! String || !name.toLowerCase().endsWith('.apk')) continue;
      if (a['state'] != null && a['state'] != 'uploaded') continue;
      final digest = a['digest'];
      return UpdateInfo(
        version: version,
        notes: ((json['body'] as String?) ?? '').trim(),
        apkUrl: Uri.parse(url),
        apkName: name,
        size: (a['size'] as num?)?.toInt() ?? 0,
        sha256: digest is String && digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
      );
    }
    return null;
  }
}

/// 해시 계산이 끝나면 결과 하나만 받아 두는 통.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// 내려받기를 중간에 멈추려고.
class UpdateCancelToken {
  bool cancelled = false;
}

enum InstallResult {
  /// 설치 화면을 열었다.
  started,

  /// '이 앱에서 설치 허용'을 먼저 켜야 한다 (설정 화면을 열어 뒀다).
  needPermission,
}

/// GitHub에서 최신 버전을 찾아 내려받고 설치 화면을 연다. (안드로이드 전용)
class UpdateService {
  UpdateService({Uri? latestReleaseUri, MethodChannel? channel})
      : latestReleaseUri = latestReleaseUri ?? Uri.https('api.github.com', '/repos/$kUpdateRepo/releases/latest'),
        _channel = channel ?? const MethodChannel('tabgame/updater');

  final Uri latestReleaseUri;
  final MethodChannel _channel;

  /// 지금 설치된 앱의 버전.
  Future<AppVersion?> currentVersion() async {
    final name = await _channel.invokeMethod<String>('version');
    return AppVersion.tryParse(name);
  }

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..userAgent = 'TabGame-Updater';

  /// 올라와 있는 최신 릴리즈. 없거나 APK가 없으면 null. 인터넷이 안 되면 예외.
  Future<UpdateInfo?> fetchLatest() async {
    final client = _client();
    try {
      final req = await client.getUrl(latestReleaseUri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) return null; // 아직 릴리즈가 없다
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('릴리즈 정보를 못 받았어요 (${res.statusCode})');
      }
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? UpdateInfo.fromRelease(json) : null;
    } finally {
      client.close(force: true);
    }
  }

  /// 지금 버전보다 새 버전이 있으면 그 정보를, 아니면 null.
  Future<UpdateInfo?> checkForUpdate() async {
    final current = await currentVersion();
    final latest = await fetchLatest();
    if (current == null || latest == null) return null;
    return latest.version > current ? latest : null;
  }

  /// [info]의 APK를 [dir]에 내려받는다 (받는 중 진행률은 [onProgress], 0~1).
  /// 크기와 SHA-256이 맞지 않으면 파일을 지우고 예외를 던진다.
  Future<File> download(
    UpdateInfo info,
    Directory dir, {
    void Function(double progress)? onProgress,
    UpdateCancelToken? cancel,
  }) async {
    if (dir.existsSync()) dir.deleteSync(recursive: true); // 이전에 받다 만 파일은 지운다
    dir.createSync(recursive: true);
    final target = File('${dir.path}/${info.apkName}');
    final part = File('${target.path}.part');
    final client = _client();
    IOSink? sink;
    try {
      final req = await client.getUrl(info.apkUrl);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('내려받지 못했어요 (${res.statusCode})');
      }
      final total = res.contentLength > 0 ? res.contentLength : info.size;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      sink = part.openWrite();
      var received = 0;
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        if (cancel?.cancelled ?? false) throw const UpdateCancelled();
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
      hasher.close();
      await sink.flush();
      await sink.close();
      sink = null;
      if (info.size > 0 && received != info.size) {
        throw HttpException('파일이 덜 받아졌어요 ($received / ${info.size} 바이트)');
      }
      final actual = digestSink.value.toString();
      if (info.sha256 != null && actual != info.sha256) {
        throw const HttpException('내려받은 파일이 올바르지 않아요 (검증 실패)');
      }
      await part.rename(target.path);
      onProgress?.call(1);
      return target;
    } catch (_) {
      await sink?.close().catchError((_) {});
      if (part.existsSync()) part.deleteSync();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// 내려받은 APK의 설치 화면을 연다.
  Future<InstallResult> install(File apk) async {
    final r = await _channel.invokeMethod<String>('install', {'path': apk.path});
    return r == 'needPermission' ? InstallResult.needPermission : InstallResult.started;
  }
}

/// 안드로이드 앱에서만 업데이트를 지원한다 (웹·데스크톱 개발 화면에서는 끈다).
bool get updatesSupported => !kIsWeb && Platform.isAndroid;
