import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/update/update_service.dart';

/// 현재 버전을 정해 두고 나머지(GitHub 확인·내려받기)는 진짜 코드를 쓰는 서비스.
class _FixedVersionService extends UpdateService {
  _FixedVersionService(this.version, Uri releaseUri) : super(latestReleaseUri: releaseUri);

  final String version;

  @override
  Future<AppVersion?> currentVersion() async => AppVersion.tryParse(version);
}

Map<String, dynamic> _release(String tag, {String? digest, int size = 5, String assetName = 'TabGame-1.0.1.apk', String url = 'http://x/a.apk'}) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'body': '고친 점',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'http://x/notes.txt', 'size': 1, 'state': 'uploaded'},
        {
          'name': assetName,
          'browser_download_url': url,
          'size': size,
          'state': 'uploaded',
          if (digest != null) 'digest': digest,
        },
      ],
    };

void main() {
  group('AppVersion', () {
    test('v 접두사와 빌드 번호가 있어도 읽는다', () {
      expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('1.0.0+7').toString(), '1.0.0');
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });

    test('숫자로 비교한다 (1.10.0 > 1.9.0)', () {
      expect(AppVersion.tryParse('1.10.0')! > AppVersion.tryParse('1.9.0')!, isTrue);
      expect(AppVersion.tryParse('2.0.0')! > AppVersion.tryParse('1.99.99')!, isTrue);
      expect(AppVersion.tryParse('1.0.1')! > AppVersion.tryParse('1.0.1')!, isFalse);
      expect(AppVersion.tryParse('v1.0.0'), AppVersion.tryParse('1.0.0+3'));
    });
  });

  group('UpdateInfo.fromRelease', () {
    test('APK 자산과 SHA-256, 크기, 설명을 꺼낸다', () {
      final info = UpdateInfo.fromRelease(_release('v1.0.1', digest: 'sha256:ABCDEF', size: 123))!;
      expect(info.version.toString(), '1.0.1');
      expect(info.apkName, 'TabGame-1.0.1.apk');
      expect(info.size, 123);
      expect(info.sha256, 'abcdef');
      expect(info.notes, '고친 점');
      expect(info.apkUrl.toString(), 'http://x/a.apk');
    });

    test('APK가 없거나 초안·시험판·이상한 태그면 건너뛴다', () {
      expect(UpdateInfo.fromRelease({..._release('v1.0.1'), 'assets': []}), isNull);
      expect(UpdateInfo.fromRelease({..._release('v1.0.1'), 'draft': true}), isNull);
      expect(UpdateInfo.fromRelease({..._release('v1.0.1'), 'prerelease': true}), isNull);
      expect(UpdateInfo.fromRelease(_release('nightly')), isNull);
    });

    test('digest가 없어도 된다', () {
      expect(UpdateInfo.fromRelease(_release('v1.0.1'))!.sha256, isNull);
    });
  });

  group('GitHub 서버와 주고받기 (내 컴퓨터의 가짜 서버)', () {
    late HttpServer server;
    late Directory tmp;
    final apkBytes = utf8.encode('가짜 APK 내용' * 5000);
    var releaseJson = <String, dynamic>{};
    var apkStatus = 200;

    Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    setUp(() async {
      apkStatus = 200;
      tmp = Directory.systemTemp.createTempSync('tabgame_update_test');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (req.uri.path == '/latest') {
          req.response
            ..statusCode = releaseJson.isEmpty ? 404 : 200
            ..write(jsonEncode(releaseJson));
        } else if (req.uri.path == '/app.apk') {
          req.response.statusCode = apkStatus;
          if (apkStatus == 200) req.response.add(apkBytes);
        }
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      tmp.deleteSync(recursive: true);
    });

    UpdateInfo info({String? sha, int? size}) => UpdateInfo(
          version: const AppVersion(1, 0, 1),
          notes: '',
          apkUrl: at('/app.apk'),
          apkName: 'TabGame-1.0.1.apk',
          size: size ?? apkBytes.length,
          sha256: sha ?? sha256.convert(apkBytes).toString(),
        );

    test('새 버전이 올라와 있으면 알려 준다', () async {
      releaseJson = _release('v1.0.1', url: at('/app.apk').toString());
      final update = await _FixedVersionService('1.0.0', at('/latest')).checkForUpdate();
      expect(update?.version.toString(), '1.0.1');
    });

    test('같거나 더 높은 버전이면 알리지 않는다', () async {
      releaseJson = _release('v1.0.1', url: at('/app.apk').toString());
      expect(await _FixedVersionService('1.0.1', at('/latest')).checkForUpdate(), isNull);
      expect(await _FixedVersionService('1.1.0', at('/latest')).checkForUpdate(), isNull);
    });

    test('릴리즈가 아직 없으면(404) 아무것도 없는 것으로 본다', () async {
      releaseJson = {};
      expect(await _FixedVersionService('1.0.0', at('/latest')).checkForUpdate(), isNull);
    });

    test('내려받으면 파일이 생기고 진행률이 1까지 올라간다', () async {
      final progress = <double>[];
      final dir = Directory('${tmp.path}/update');
      final file = await UpdateService().download(info(), dir, onProgress: progress.add);
      expect(file.readAsBytesSync(), apkBytes);
      expect(progress.last, 1.0);
      expect(dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last), ['TabGame-1.0.1.apk']);
    });

    test('SHA-256이 다르면 실패하고 파일을 남기지 않는다', () async {
      final dir = Directory('${tmp.path}/update');
      await expectLater(
        UpdateService().download(info(sha: 'deadbeef'), dir),
        throwsA(isA<HttpException>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('크기가 다르면 실패한다', () async {
      final dir = Directory('${tmp.path}/update');
      await expectLater(
        UpdateService().download(info(size: apkBytes.length + 1), dir),
        throwsA(isA<HttpException>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('서버 오류면 실패한다', () async {
      apkStatus = 500;
      await expectLater(
        UpdateService().download(info(), Directory('${tmp.path}/update')),
        throwsA(isA<HttpException>()),
      );
    });

    test('취소하면 UpdateCancelled이고 파일이 남지 않는다', () async {
      final dir = Directory('${tmp.path}/update');
      final token = UpdateCancelToken()..cancelled = true;
      await expectLater(
        UpdateService().download(info(), dir, cancel: token),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('이전에 받던 파일은 새로 받을 때 지운다', () async {
      final dir = Directory('${tmp.path}/update')..createSync();
      File('${dir.path}/old.apk').writeAsStringSync('old');
      await UpdateService().download(info(), dir);
      expect(File('${dir.path}/old.apk').existsSync(), isFalse);
    });
  });
}
