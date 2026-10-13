"""리듬 검사단 '옆으로 휘두르기' 그림 에셋 준비 도구.

tool/art_src/rhythm_side_swing.webp (어두운 바탕 + 은은한 광채, 위 줄 = 준비 자세 4명 /
아래 줄 = 푸른 궤적과 함께 옆으로 휘두르는 자세 4명)에서 배경을 지우고 스프라이트를 오려
assets/rhythm/art/ 에 c{0-3}_side_ready.png, c{0-3}_side_swing.png 와 art_side.json 으로 저장한다.
(아직 게임 코드에서는 쓰지 않는다 — 나중에 쓰려고 준비만 해 둔 것)

    python tool/prepare_rhythm_side_art.py            # 실제 생성
    python tool/prepare_rhythm_side_art.py --sheet    # 확인용 연두색 바탕 시트 (art_src/_check_side.png)

배경 제거 방법: 윤곽선(검은 테두리)은 바로 바깥의 광채보다 어두워서 밝기 변화가 크다. 그래서 화면 가장자리에서
'밝기가 거의 안 변하는 곳'만 따라 번지게 해 바깥 배경을 구하고, 나머지를 스프라이트로 본다.
푸른 궤적은 빛이라서, 밝기를 투명도로 바꿔 어두운 테두리가 남지 않게 한다.

필요: Pillow, numpy
"""
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

from prepare_rhythm_art import OUT, SRC, save_png

EDGE_T = 0.08  # 밝기(제곱근) 변화가 이보다 크면 윤곽으로 본다


def foreground_mask(arr):
    h, w = arr.shape[:2]
    lum = np.sqrt(arr.astype(np.float32).mean(2) / 255.0)  # 어두운 쪽을 끌어올려 윤곽을 잘 보이게
    gx = np.zeros_like(lum)
    gy = np.zeros_like(lum)
    gx[:, 2:-2] = np.abs(lum[:, 4:] - lum[:, :-4])
    gy[2:-2, :] = np.abs(lum[4:, :] - lum[:-4, :])
    edge = np.maximum(gx, gy) > EDGE_T
    edge = np.array(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    free = (~edge).ravel()
    bg = np.zeros(h * w, bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            p = y * w + x
            if free[p] and not bg[p]:
                bg[p] = True
                dq.append(p)
    for y in range(h):
        for x in (0, w - 1):
            p = y * w + x
            if free[p] and not bg[p]:
                bg[p] = True
                dq.append(p)
    while dq:
        p = dq.popleft()
        y, x = divmod(p, w)
        for q in ((p - w) if y > 0 else -1, (p + w) if y < h - 1 else -1, (p - 1) if x > 0 else -1, (p + 1) if x < w - 1 else -1):
            if q >= 0 and free[q] and not bg[q]:
                bg[q] = True
                dq.append(q)
    return ~bg.reshape(h, w), edge


def smoke_mask(arr, fg, edge):
    """궤적과 이어진, 윤곽선 없는 어두운 영역(겨드랑이 밑 그림자)을 구한다.
    윤곽선으로 나뉜 영역 중 푸른 궤적 픽셀이 들어 있는 것의, 푸르지 않은 픽셀이 그림자다."""
    h, w = fg.shape
    r, g, b = (arr[..., i].astype(np.int32) for i in range(3))
    blue = fg & (b > r + 25) & (b > 40)
    free = (fg & ~edge).ravel()
    blue_f = blue.ravel()
    seen = np.zeros(h * w, bool)
    smoke = np.zeros(h * w, bool)
    for s0 in np.flatnonzero(free):
        if seen[s0]:
            continue
        seen[s0] = True
        comp = [s0]
        dq = deque([s0])
        while dq:
            p = dq.popleft()
            y, x = divmod(p, w)
            for q in ((p - w) if y > 0 else -1, (p + w) if y < h - 1 else -1, (p - 1) if x > 0 else -1, (p + 1) if x < w - 1 else -1):
                if q >= 0 and free[q] and not seen[q]:
                    seen[q] = True
                    comp.append(q)
                    dq.append(q)
        idx = np.array(comp)
        if blue_f[idx].sum() > 200:
            smoke[idx[~blue_f[idx]]] = True
    return smoke.reshape(h, w)


def glow_to_alpha(arr, fg):
    """푸른 궤적 픽셀은 밝기 = 투명도로 바꾼다 (어두운 파랑은 거의 투명, 밝은 파랑은 불투명)."""
    r, g, b = (arr[..., i].astype(np.float32) for i in range(3))
    effect = fg & (b > r + 25) & (b > 40)
    mx = np.maximum(np.maximum(r, g), b)
    alpha = np.where(fg, 255.0, 0.0)
    alpha[effect] = np.clip((mx[effect] - 45) * 2.0, 0, 255)
    rgb = arr.astype(np.float32)
    scale = np.where(effect, 255.0 / np.maximum(mx, 1.0), 1.0)
    rgb = np.clip(rgb * scale[..., None], 0, 255)
    return np.dstack([rgb, alpha]).astype(np.uint8)


def sprites(fg, min_area=5000):
    """연결된 덩어리마다 (면적, 상자) — 위 줄/아래 줄, 왼쪽→오른쪽 순서로 돌려준다."""
    h, w = fg.shape
    flat = fg.ravel()
    seen = np.zeros(h * w, bool)
    found = []
    for s in np.flatnonzero(flat):
        if seen[s]:
            continue
        seen[s] = True
        dq = deque([s])
        comp = [s]
        while dq:
            p = dq.popleft()
            y, x = divmod(p, w)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w:
                        q = yy * w + xx
                        if flat[q] and not seen[q]:
                            seen[q] = True
                            comp.append(q)
                            dq.append(q)
        if len(comp) < min_area:
            continue
        idx = np.array(comp)
        ys, xs = np.divmod(idx, w)
        found.append((len(comp), (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), idx))
    top = sorted([f for f in found if (f[1][1] + f[1][3]) / 2 < h / 2], key=lambda f: f[1][0])
    bottom = sorted([f for f in found if (f[1][1] + f[1][3]) / 2 >= h / 2], key=lambda f: f[1][0])
    return top, bottom


def feet(arr, kind):
    """발 위치: 아래쪽 15%에서 어두운(장화) 픽셀의 가운데 x와 맨 아래 y."""
    a = arr[..., 3] > 0
    lum = arr[..., :3].astype(int).sum(axis=2) / 3
    h, w = a.shape
    ys, xs = np.nonzero(a)
    top, bot = ys.min(), ys.max()
    band = np.zeros_like(a)
    band[int(bot - (bot - top) * 0.15): bot + 1, :] = True
    if kind == 'swing':
        band[:, int(w * 0.8):] = False
    m = a & band & (lum < 135)
    yy, xx = np.nonzero(m)
    return float((xx.min() + xx.max()) / 2), float(yy.max())


def stance_width(arr):
    """두 발(장화) 사이 너비 — 자세가 달라도 거의 같아서 그림 크기를 맞추는 기준으로 쓴다."""
    a = arr[..., 3] > 0
    lum = arr[..., :3].astype(int).sum(axis=2) / 3
    ys, xs = np.nonzero(a)
    top, bot = ys.min(), ys.max()
    band = np.zeros_like(a)
    band[int(bot - (bot - top) * 0.15): bot + 1, :] = True
    band[:, int(a.shape[1] * 0.8):] = False
    yy, xx = np.nonzero(a & band & (lum < 135))
    return float(xx.max() - xx.min())


def main():
    sheet = '--sheet' in sys.argv
    src = np.array(Image.open(os.path.join(SRC, 'rhythm_side_swing.webp')).convert('RGB'))
    print('removing background ...')
    fg, edge = foreground_mask(src)
    smoke = smoke_mask(src, fg, edge)
    # 그림자 둘레의 한두 겹도 같이 지우되, 검은 윤곽선(아주 어두운 줄)은 건드리지 않는다
    near = np.array(Image.fromarray((smoke * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    smoke |= near & fg & (src.astype(np.int32).mean(2) > 28) & ~(src[..., 2].astype(np.int32) > src[..., 0].astype(np.int32) + 25)
    fg = fg & ~smoke
    rgba = glow_to_alpha(src, fg)
    top, bottom = sprites(fg)
    print('ready', len(top), 'swing', len(bottom))
    if len(top) != 4 or len(bottom) != 4:
        sys.exit('스프라이트가 4+4개로 나뉘지 않았다 — 원본 배치나 임계값을 확인할 것')

    meta = {}
    scales = {}
    for kind, group in (('ready', top), ('swing', bottom)):
        for i, (_, (x0, y0, x1, y1), idx) in enumerate(group):
            keep = np.zeros(fg.shape, bool)
            keep.ravel()[idx] = True
            sub = rgba[y0:y1, x0:x1].copy()
            sub[..., 3] = np.where(keep[y0:y1, x0:x1], sub[..., 3], 0)
            name = f'c{i}_side_{kind}.png'
            save_png(sub, name)
            fx, fy = feet(sub, kind)
            meta[name] = {'w': int(sub.shape[1]), 'h': int(sub.shape[0]), 'footX': fx, 'footY': fy}
            if kind == 'ready':
                # 기존 준비 자세(c{i}_windup)와 발 간격이 같아지도록 배율을 구한다. 휘두르는 자세도 같은 배율을 쓴다.
                old = np.array(Image.open(os.path.join(OUT, f'c{i}_windup.png')).convert('RGBA'))
                scales[i] = round(stance_width(old) / stance_width(sub), 3)
            meta[name]['scale'] = scales[i]
            if kind == 'ready':
                # 칼끝: 칼이 왼쪽 위를 향하므로 가장 왼쪽 픽셀들의 가운데
                ys_, xs_ = np.nonzero(sub[..., 3] > 0)
                l = xs_.min()
                sel = xs_ <= l + 6
                meta[name]['tipX'] = float(l + 6)
                meta[name]['tipY'] = float(np.median(ys_[sel]))
    with open(os.path.join(OUT, 'art_side.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=1)

    if sheet:
        W = 1800
        canvas = Image.new('RGBA', (W, 1100), (60, 200, 90, 255))
        x, y, rowh = 10, 10, 0
        for name in sorted(meta):
            im = Image.open(os.path.join(OUT, name))
            if x + im.width > W:
                x, y, rowh = 10, y + rowh + 10, 0
            canvas.alpha_composite(im, (x, y))
            x += im.width + 10
            rowh = max(rowh, im.height)
        canvas.convert('RGB').save(os.path.join(SRC, '_check_side.png'))
    print('done ->', OUT)


if __name__ == '__main__':
    main()
