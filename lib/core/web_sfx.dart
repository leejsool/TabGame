/// 웹에서 짧은 효과음을 가볍게 트는 재생기 (앱에서는 아무것도 하지 않는다).
///
/// audioplayers의 웹 재생기는 재생기 하나를 만들 때마다 오디오 엔진(AudioContext)을 새로 만들어서, 하나에 0.5~1초씩
/// 화면이 멈춘다 (야추 화면은 효과음이 많아 열 때 몇 초씩 끊겼다). 그래서 웹에서는 엔진 하나를 같이 쓰고,
/// 소리 파일은 한 번만 풀어 두었다가 틀 때마다 가벼운 재생 마디만 만든다.
library;

export 'web_sfx_stub.dart' if (dart.library.js_interop) 'web_sfx_web.dart';
