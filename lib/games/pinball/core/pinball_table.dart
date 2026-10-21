import 'dart:math';

/// 핀볼 판의 크기 (가상 좌표 = 판 그림 `assets/pinball/board.png`의 픽셀). 왼쪽 위가 (0,0), 아래쪽이 y가 커지는 쪽.
const double kTableW = 618;
const double kTableH = 1461;

/// 공 반지름.
const double kBallR = 10;

/// 공이 대기하는 발사 통로의 가운데 x와 바닥 높이, 통로의 안쪽 벽 x.
const double kLaneX = 597;
const double kLaneFloorY = 1385;
const double kLaneInnerX = 583;

/// 공이 이 높이보다 아래로 내려가면 (통로 밖에서) 떨어진 것으로 본다.
const double kDrainY = 1338;

/// 판 왼쪽 부품을 오른쪽으로 뒤집을 때 쓰는 값 (판 가운데 x=308).
double mirrorX(double x) => 616 - x;

/// 선분 벽. [kick]이 있으면 공을 그만큼의 속도로 튕겨 내는 슬링샷이다.
class Wall {
  const Wall(this.ax, this.ay, this.bx, this.by, {this.bounce = 0.45, this.kick = 0, this.sling = -1, this.visible = true, this.gate = false, this.nx = 0, this.ny = 0});

  final double ax, ay, bx, by;
  final double bounce;
  final double kick;

  /// 슬링샷 번호 (0=왼쪽, 1=오른쪽). 슬링샷이 아니면 -1.
  final int sling;

  /// 판 그림 위에 따로 그려야 하는 벽인지 (그림에 이미 레일이 그려져 있으니 보통은 안 그린다).
  final bool visible;

  /// 한쪽으로만 지나갈 수 있는 문 (세로 선분): 오른쪽으로 가는 공만 막고, 왼쪽으로 가는 공은 지나간다.
  final bool gate;

  /// 슬링샷이 공을 밀어내는 쪽 (판 안쪽)을 가리키는 단위 벡터. 반대쪽에서 맞으면 튕겨 내지 않는다.
  final double nx, ny;
}

/// 동그란 장애물: 범퍼(튕겨 냄) · 기둥(그냥 튕김).
class Disc {
  const Disc(this.x, this.y, this.r);

  final double x, y, r;
}

/// 한 번 맞으면 눕는 표적. [bank]는 묶음 번호 (0=아래 접시의 알약 4개, 1=왼쪽, 2=오른쪽). 묶음을 다 쓰러뜨리면 보너스.
class Target {
  const Target(this.x, this.y, this.r, this.bank);

  final double x, y, r;
  final int bank;
}

enum SensorKind { lane, orbitIn, orbitOut }

/// 공이 지나가면 알아채는 자리 (별 불빛 롤오버, 궤도 레인의 들어가는 곳·나오는 곳). 공은 그냥 지나간다.
class Sensor {
  const Sensor(this.x, this.y, this.r, this.kind, this.index);

  final double x, y, r;
  final SensorKind kind;

  /// 레인 번호(0~3) 또는 궤도 번호(0=왼쪽, 1=오른쪽).
  final int index;
}

/// 공이 지나가면 빙글 도는 판 (돌 때마다 점수).
class SpinnerSpec {
  const SpinnerSpec(this.x, this.y, this.w);

  final double x, y, w;
}

/// 플리퍼 설계: 축 위치·길이·쉬는 각도와 올린 각도 (라디안, x축 기준 아래쪽이 +).
class FlipperSpec {
  const FlipperSpec({required this.px, required this.py, required this.length, required this.restAngle, required this.upAngle, required this.left});

  final double px, py, length, restAngle, upAngle;
  final bool left;
}

/// 판 하나의 모양.
class PinballTable {
  const PinballTable({
    required this.walls,
    required this.bumpers,
    required this.targets,
    required this.posts,
    required this.flippers,
    required this.sensors,
    required this.spinners,
    required this.saucer,
  });

  final List<Wall> walls;

  /// 범퍼. 앞의 5개는 색깔 돔 부품이고, 나머지 셋은 그림에 그려진 큰 공(마스터볼·빨간 몬스터볼·가운데 몬스터볼).
  final List<Disc> bumpers;
  final List<Target> targets;
  final List<Disc> posts;
  final List<FlipperSpec> flippers;
  final List<Sensor> sensors;
  final List<SpinnerSpec> spinners;

  /// 가운데 위쪽 "R" 마크 자리의 구멍 (공이 빨려 들어갔다 나온다).
  final Disc saucer;

  int get bankCount => targets.map((t) => t.bank).fold(0, max) + 1;

  /// 포켓몬 판.
  factory PinballTable.standard() {
    final walls = <Wall>[];
    // 바깥 테두리: 왼쪽 벽과, 판 그림의 윗부분 모양을 따라가는 천장
    const top = [(34.0, 330.0), (34.0, 130.0), (52.0, 72.0), (92.0, 36.0), (150.0, 18.0), (210.0, 22.0), (262.0, 46.0), (302.0, 64.0), (360.0, 58.0), (430.0, 48.0), (500.0, 38.0), (558.0, 44.0), (594.0, 78.0), (612.0, 140.0)];
    for (var i = 0; i + 1 < top.length; i++) {
      walls.add(Wall(top[i].$1, top[i].$2, top[i + 1].$1, top[i + 1].$2, bounce: 0.4, visible: false));
    }
    walls.add(const Wall(34, 330, 34, kTableH, visible: false));
    // 발사 통로: 바깥 벽, 안쪽 벽, 바닥, 위쪽 출구의 한쪽 문
    walls.add(const Wall(612, 140, 612, kLaneFloorY, visible: false));
    walls.add(const Wall(kLaneInnerX, 270, kLaneInnerX, kLaneFloorY, visible: false));
    walls.add(const Wall(kLaneInnerX, kLaneFloorY, 612, kLaneFloorY, bounce: 0.1, visible: false));
    walls.add(const Wall(kLaneInnerX, 40, kLaneInnerX, 270, gate: true, visible: false));

    // 위쪽 양옆의 궤도 레인 (왼쪽 → 오른쪽은 x를 616-x로 뒤집은 모양, 바깥 벽은 이미 있음)
    walls.add(const Wall(96, 620, 96, 335, bounce: 0.3, visible: false));
    walls.add(const Wall(96, 620, 118, 652, bounce: 0.3, visible: false));
    walls.add(const Wall(34, 300, 96, 335, bounce: 0.3, visible: false)); // 지붕: 위에서 떨어진 공은 판 쪽으로 미끄러진다
    walls.add(Wall(mirrorX(96), 620, mirrorX(96), 335, bounce: 0.3, visible: false));
    walls.add(Wall(mirrorX(96), 620, mirrorX(118), 652, bounce: 0.3, visible: false));
    walls.add(Wall(kLaneInnerX, 300, mirrorX(96), 335, bounce: 0.3, visible: false));

    // 색깔 길(초록·파랑 / 노랑·주황): 가운데 깔때기 쪽으로 모이는 비스듬한 칸막이들
    for (final left in [true, false]) {
      double mx(double x) => left ? x : mirrorX(x);
      walls.add(Wall(mx(112), 585, mx(176), 845, bounce: 0.3, visible: false));
      walls.add(Wall(mx(186), 585, mx(246), 845, bounce: 0.3, visible: false));
      walls.add(Wall(mx(232), 585, mx(290), 830, bounce: 0.3, visible: false));
    }

    // 아래쪽 안내벽(인레인/아웃레인)과 슬링샷
    for (final left in [true, false]) {
      double mx(double x) => left ? x : mirrorX(x);
      walls.add(Wall(mx(76), 1108, mx(196), 1212, visible: false));
      final nxv = left ? 0.655 : -0.655;
      walls.add(Wall(mx(113), 1095, mx(192), 1163, kick: 880, sling: left ? 0 : 1, bounce: 0.35, nx: nxv, ny: -0.756, visible: false));
    }
    return PinballTable(
      walls: walls,
      bumpers: const [
        Disc(238, 318, 26), Disc(422, 318, 26), Disc(330, 262, 26), Disc(250, 445, 26), Disc(410, 445, 26),
        Disc(178, 365, 28), Disc(162, 532, 55), Disc(333, 730, 46),
      ],
      targets: const [
        Target(244, 893, 17, 0), Target(352, 878, 17, 0), Target(261, 968, 17, 0), Target(377, 924, 17, 0),
        Target(70, 720, 11, 1), Target(70, 770, 11, 1), Target(70, 820, 11, 1),
        Target(546, 720, 11, 2), Target(546, 770, 11, 2), Target(546, 820, 11, 2),
      ],
      posts: const [Disc(113, 1095, 7), Disc(503, 1095, 7), Disc(192, 1163, 7), Disc(424, 1163, 7), Disc(150, 1000, 8), Disc(466, 1000, 8)],
      flippers: const [
        FlipperSpec(px: 203, py: 1216, length: 84, restAngle: 28 * pi / 180, upAngle: -32 * pi / 180, left: true),
        FlipperSpec(px: 413, py: 1216, length: 84, restAngle: pi - 28 * pi / 180, upAngle: pi + 32 * pi / 180, left: false),
      ],
      sensors: const [
        Sensor(313, 525, 15, SensorKind.lane, 0),
        Sensor(284, 578, 15, SensorKind.lane, 1),
        Sensor(346, 578, 15, SensorKind.lane, 2),
        Sensor(314, 630, 15, SensorKind.lane, 3),
        Sensor(65, 625, 18, SensorKind.orbitIn, 0),
        Sensor(551, 625, 18, SensorKind.orbitIn, 1),
        Sensor(65, 365, 18, SensorKind.orbitOut, 0),
        Sensor(551, 365, 18, SensorKind.orbitOut, 1),
      ],
      spinners: const [SpinnerSpec(65, 490, 44), SpinnerSpec(551, 490, 44)],
      saucer: const Disc(326, 414, 19),
    );
  }
}
