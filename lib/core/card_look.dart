/// 카드 앞면의 모양(스타일). 설정에서 바꾸고, 프리셀·솔리테어의 모든 카드가 따른다.
enum CardStyle {
  bicycle('바이시클', '정통 트럼프: 왕·여왕·잭 그림과 장식 에이스'),
  simple('심플', '그림 없이 글자와 무늬만 깔끔하게'),
  cute('귀여운', '동글동글 귀여운 얼굴의 왕·여왕·잭');

  const CardStyle(this.label, this.description);

  final String label;
  final String description;
}

/// 카드 뒷면 디자인. 솔리테어의 뒤집힌 카드와 설정 미리보기에 적용한다.
enum CardBackStyle {
  classic('클래식', '파란 마름모와 별'),
  floral('플로럴', '붉고 푸른 대칭 꽃무늬'),
  ornate('오너먼트', '정교한 클래식 장식'),
  vortex('골드 소용돌이', '검은 바탕과 황금빛 회오리'),
  blueOrb('블루 오브', '파란 테두리와 중앙 구체');

  const CardBackStyle(this.label, this.description);

  final String label;
  final String description;
}

/// 지금 선택된 카드 모양. (그리는 쪽에서 바로 읽을 수 있게 전역으로 둔다. [Settings]가 바뀔 때 갱신한다)
class CardLook {
  CardLook._();

  static CardStyle style = CardStyle.bicycle;
  static CardBackStyle backStyle = CardBackStyle.classic;

  /// 무늬마다 다른 색 (♠ 검정, ♥ 빨강, ♣ 초록, ♦ 파랑)으로 구분하기 쉽게.
  static bool fourColor = false;
}
