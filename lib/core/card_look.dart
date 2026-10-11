/// 카드 앞면의 모양(스타일). 설정에서 바꾸고, 프리셀·솔리테어의 모든 카드가 따른다.
enum CardStyle {
  bicycle('바이시클', '정통 트럼프: 왕·여왕·잭 그림과 장식 에이스'),
  simple('심플', '그림 없이 글자와 무늬만 깔끔하게'),
  cute('귀여운', '동글동글 귀여운 얼굴의 왕·여왕·잭');

  const CardStyle(this.label, this.description);

  final String label;
  final String description;
}

/// 지금 선택된 카드 모양. (그리는 쪽에서 바로 읽을 수 있게 전역으로 둔다. [Settings]가 바뀔 때 갱신한다)
class CardLook {
  CardLook._();

  static CardStyle style = CardStyle.bicycle;

  /// 무늬마다 다른 색 (♠ 검정, ♥ 빨강, ♣ 초록, ♦ 파랑)으로 구분하기 쉽게.
  static bool fourColor = false;
}
