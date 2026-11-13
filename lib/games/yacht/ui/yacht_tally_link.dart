import 'package:flutter/foundation.dart';

/// 점수판의 정산(끝난 뒤 점수가 합계로 내려오는 모습)과 화면의 단추를 이어 주는 끈.
/// 정산 중에는 "적기" 단추가 "건너뛰기"로 바뀌고, 누르면 점수판이 최종 합계로 바로 간다.
class YachtTallyLink {
  /// 지금 정산 중인가.
  final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  /// 정산을 끝까지 건너뛴다 (점수판이 채워 준다).
  VoidCallback? skip;

  void dispose() => running.dispose();
}
