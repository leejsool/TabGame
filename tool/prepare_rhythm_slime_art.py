"""리듬 검사단 슬라임(적) 그림 에셋 준비 도구.

tool/art_src/rhythm_slime.webp (배경이 이미 투명한 2x2 시트)에서 네 자세를 오려
assets/rhythm/art/ 에 slime_idle.png(기본) / slime_ready.png(공격 준비) / slime_attack.png(공격) /
slime_hit.png(피격) 와 art_slime.json 으로 저장한다. 피격 그림에 같이 그려진 칼은 지운다.
(아직 게임 코드에서는 쓰지 않는다)

    python tool/prepare_rhythm_slime_art.py            # 실제 생성
    python tool/prepare_rhythm_slime_art.py --sheet    # 확인용 연두색 바탕 시트 (art_src/_check_slime.png)

필요: Pillow, numpy
"""
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

from prepare_rhythm_art import OUT, SRC, save_png

# 시트를 네 칸으로 나누는 경계 (공격 자세의 궤적이 가운데 선을 넘으므로 x는 810)
SPLIT_X, SPLIT_Y = 810, 510
NAMES = [['idle', 'ready'], ['attack', 'hit']]


def dilate(mask, size=5):
    return np.array(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(size))) > 0


def erase_sword(rgba, x0, y0):
    """피격 그림에서 칼(윤곽선·날·자루)을 지운다. 슬라임 몸·충격 무늬(노랑/주황)·물방울(파랑)은 남긴다.
    (x0, y0)는 이 칸의 시트 좌표 원점."""
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3].astype(np.int32)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    opaque = rgba[..., 3] > 0
    xs = np.arange(w)[None, :] + x0
    right = xs >= 1235  # 슬라임 몸의 오른쪽 윤곽선은 x≈1217까지
    grey = (mx - mn) < 45  # 검정 윤곽, 은빛 날
    handle = xs >= 1440  # 자루(갈색·황토색) 전체
    sword = opaque & right & (grey | handle)
    sword = dilate(sword, 5)  # 가장자리 한두 겹
    yellow = (rgb[..., 0] > 200) & ((mx - mn) >= 70)  # 충격 무늬는 지키기
    sword &= opaque & right & ~yellow | (opaque & handle)
    out = rgba.copy()
    out[sword, 3] = 0
    return out


def largest_component_bottom(alpha_mask):
    """가장 큰 덩어리(= 몸)의 맨 아래 y와, 그 아래쪽 8% 픽셀들의 가운데 x."""
    h, w = alpha_mask.shape
    flat = alpha_mask.ravel()
    seen = np.zeros(h * w, bool)
    best = None
    for s in np.flatnonzero(flat):
        if seen[s]:
            continue
        seen[s] = True
        comp = [s]
        dq = deque([s])
        while dq:
            p = dq.popleft()
            y, x = divmod(p, w)
            for q in ((p - w) if y > 0 else -1, (p + w) if y < h - 1 else -1, (p - 1) if x > 0 else -1, (p + 1) if x < w - 1 else -1):
                if q >= 0 and flat[q] and not seen[q]:
                    seen[q] = True
                    comp.append(q)
                    dq.append(q)
        if best is None or len(comp) > len(best):
            best = comp
    ys, xs = np.divmod(np.array(best), w)
    bot = ys.max()
    sel = ys >= bot - max(2, int((bot - ys.min()) * 0.08))
    return float(xs[sel].mean()), float(bot), xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def main():
    sheet = '--sheet' in sys.argv
    src = np.array(Image.open(os.path.join(SRC, 'rhythm_slime.webp')).convert('RGBA'))
    src[src[..., 3] < 16] = 0  # 바탕에 깔린 아주 옅은 잡티 제거
    h, w = src.shape[:2]
    meta = {}
    for r in range(2):
        for c in range(2):
            x0, x1 = (0, SPLIT_X) if c == 0 else (SPLIT_X, w)
            y0, y1 = (0, SPLIT_Y) if r == 0 else (SPLIT_Y, h)
            cell = src[y0:y1, x0:x1].copy()
            name = NAMES[r][c]
            if name == 'hit':
                cell = erase_sword(cell, x0, y0)
            ys, xs = np.nonzero(cell[..., 3] > 0)
            cell = cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            bx, by, *_ = largest_component_bottom(cell[..., 3] > 0)
            file = f'slime_{name}.png'
            save_png(cell, file)
            meta[file] = {'w': int(cell.shape[1]), 'h': int(cell.shape[0]), 'baseX': bx, 'baseY': by}
            print(file, cell.shape[1], 'x', cell.shape[0])
    with open(os.path.join(OUT, 'art_slime.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=1)

    if sheet:
        canvas = Image.new('RGBA', (2100, 400), (60, 200, 90, 255))
        x = 10
        for name in ('idle', 'ready', 'attack', 'hit'):
            im = Image.open(os.path.join(OUT, f'slime_{name}.png'))
            canvas.alpha_composite(im, (x, 10))
            x += im.width + 10
        canvas.convert('RGB').save(os.path.join(SRC, '_check_slime.png'))
    print('done ->', OUT)


if __name__ == '__main__':
    main()
