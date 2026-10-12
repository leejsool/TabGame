"""리듬 검사단 그림 에셋 준비 도구.

tool/art_src/ 의 원본 이미지에서 배경 제거(체크무늬/흰 바탕) 후 스프라이트를 오려
assets/rhythm/art/ 에 저장한다.

    python tool/prepare_rhythm_art.py            # 실제 생성
    python tool/prepare_rhythm_art.py --sheet    # 확인용 컨택트 시트도 저장 (art_src/_check_*.png)

필요: Pillow, numpy
"""
import json
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'art_src')
OUT = os.path.join(os.path.dirname(ROOT), 'assets', 'rhythm', 'art')
os.makedirs(OUT, exist_ok=True)


def neutral_bright(arr, lo=190, tol=9):
    """체크무늬/흰 바탕처럼 '밝은 무채색'인 픽셀."""
    r, g, b = arr[..., 0].astype(int), arr[..., 1].astype(int), arr[..., 2].astype(int)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    return (mn >= lo) & ((mx - mn) <= tol)


def background_mask(arr, min_inner=1200):
    """바깥과 이어진 밝은 무채색 영역(+ 충분히 큰 안쪽 구멍)을 배경으로 본다."""
    h, w = arr.shape[:2]
    cand = neutral_bright(arr)
    labels = np.zeros((h, w), np.int32)
    flat_c = cand.ravel()
    flat_l = labels.ravel()
    bg = np.zeros(h * w, bool)
    n = 0
    for start in np.flatnonzero(flat_c):
        if flat_l[start]:
            continue
        n += 1
        comp = [start]
        flat_l[start] = n
        dq = deque([start])
        touches = False
        while dq:
            p = dq.popleft()
            y, x = divmod(p, w)
            if y == 0 or x == 0 or y == h - 1 or x == w - 1:
                touches = True
            for q in ((p - w) if y > 0 else -1, (p + w) if y < h - 1 else -1, (p - 1) if x > 0 else -1, (p + 1) if x < w - 1 else -1):
                if q >= 0 and flat_c[q] and not flat_l[q]:
                    flat_l[q] = n
                    comp.append(q)
                    dq.append(q)
        if touches or len(comp) >= min_inner:
            bg[comp] = True
    return bg.reshape(h, w)


def to_rgba(arr, bg):
    """배경을 투명하게. 윤곽선 둘레의 밝은 테두리(헤일로)는 한 겹 더 지운다."""
    h, w = bg.shape
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # 배경과 맞닿은 밝은 무채색 픽셀 한 겹 제거
    near = np.zeros_like(bg)
    near[1:, :] |= bg[:-1, :]
    near[:-1, :] |= bg[1:, :]
    near[:, 1:] |= bg[:, :-1]
    near[:, :-1] |= bg[:, 1:]
    soft = near & ~bg & neutral_bright(arr, lo=170, tol=14)
    alpha[soft] = 0
    out = np.dstack([arr, alpha]).astype(np.uint8)
    return out


def dilate(mask, r):
    out = mask.copy()
    for _ in range(r):
        m = out.copy()
        m[1:, :] |= out[:-1, :]
        m[:-1, :] |= out[1:, :]
        m[:, 1:] |= out[:, :-1]
        m[:, :-1] |= out[:, 1:]
        out = m
    return out


def components(mask):
    """True 픽셀의 연결 덩어리들 → [(좌표 인덱스 배열)]"""
    h, w = mask.shape
    flat = mask.ravel()
    seen = np.zeros(h * w, bool)
    comps = []
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
        comps.append(np.array(comp))
    return comps


def cut_bands(rgba, y0, y1, splits, shrink=4):
    """세로 구간(y0~y1)을 splits(경계 x 목록)로 나눠 각 칸에서 스프라이트를 오린다.
    칸 안에서 작은 찌꺼기(옆 인물의 궤적선 끝 등)는 버린다."""
    xs_edges = [0] + list(splits) + [rgba.shape[1]]
    out = []
    for i in range(len(xs_edges) - 1):
        x0, x1 = xs_edges[i], xs_edges[i + 1]
        sub = rgba[y0:y1, x0:x1].copy()
        opaque = sub[..., 3] > 0
        small = opaque[::shrink, ::shrink]
        grown = dilate(small, 3)
        gh, gw = grown.shape
        keep_small = np.zeros_like(grown)
        for c in components(grown):
            if len(c) >= 120:
                keep_small.ravel()[c] = True
        big = np.kron(keep_small, np.ones((shrink, shrink), bool))[: opaque.shape[0], : opaque.shape[1]]
        keep = opaque & big
        sub[..., 3] = np.where(keep, sub[..., 3], 0)
        # 원본 패널 경계선이 맨 윗줄에 가늘게 남는 경우가 있어, 갑자기 넓은 맨 윗줄은 지운다
        for _ in range(4):
            rows = np.flatnonzero(keep.any(axis=1))
            r0 = rows[0]
            if keep[r0].sum() > 2.2 * max(1, keep[min(r0 + 3, keep.shape[0] - 1)].sum()):
                keep[r0] = False
                sub[r0, :, 3] = 0
            else:
                break
        ys, xs = np.nonzero(keep)
        cx0, cx1, cy0, cy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        out.append((sub[cy0:cy1, cx0:cx1], (x0 + cx0, y0 + cy0, x0 + cx1, y0 + cy1)))
    return out


def save_png(arr, name):
    Image.fromarray(arr, 'RGBA').save(os.path.join(OUT, name), optimize=True)


def main():
    sheet = '--sheet' in sys.argv
    a = np.array(Image.open(os.path.join(SRC, 'rhythm_bg_dummies_idle.webp')).convert('RGB'))
    b = np.array(Image.open(os.path.join(SRC, 'rhythm_windup_strike.webp')).convert('RGB'))

    # ── 배경: 위쪽 그림만 쓰고, 아래로는 가운데 흙바닥 조각을 거울처럼 이어 붙여 화면 비율에 맞춘다 ──
    plate = a[:556]
    ph, pw = plate.shape[:2]
    target_h = 1000
    patch = plate[420:ph, 380:1156]  # 흙바닥과 풀 몇 포기만 있는 조각
    pt, pwid = patch.shape[:2]
    # 가로로 거울 타일링해서 전체 너비로
    tiles = [patch]
    while sum(t.shape[1] for t in tiles) < pw + pwid:
        tiles.append(tiles[-1][:, ::-1])
    row = np.hstack(tiles)
    off = (row.shape[1] - pw) // 2
    row = row[:, off : off + pw]
    # 세로로도 거울 타일링: 이음매(ph) 아래로는 조각을 뒤집어 이어 붙인다
    ext_rows = []
    cur = row[::-1]
    total = 0
    while ph + total < target_h + 60:
        ext_rows.append(cur)
        total += cur.shape[0]
        cur = cur[::-1]
    ext = np.vstack(ext_rows)  # ext[0]은 plate의 맨 아랫줄과 같은 줄
    tiled = np.vstack([row, ext])  # row 는 plate 의 420~555 줄에 해당
    full_h = 420 + tiled.shape[0]
    canvas = np.zeros((full_h, pw, 3), np.uint8)
    canvas[:ph] = plate
    canvas[ph:] = tiled[ph - 420 :]
    # 이음매 위 60줄에서 plate → 타일링한 흙바닥으로 서서히 바꾼다 (가장자리의 소품이 자연스럽게 사라짐)
    seam = ph
    for y in range(seam - 60, seam):
        t = (y - (seam - 60)) / 60.0
        t = t * t * (3 - 2 * t)
        canvas[y] = (plate[y].astype(float) * (1 - t) + tiled[y - 420].astype(float) * t).astype(np.uint8)
    bg = canvas[:target_h]
    Image.fromarray(bg, 'RGB').save(os.path.join(OUT, 'bg.png'), optimize=True)
    print('bg', bg.shape)

    # ── 허수아비 (아래 왼쪽) ──
    print('removing background: dummies/idle ...')
    bottom = a[562:]
    bm = background_mask(bottom)
    rgba_a = to_rgba(bottom, bm)
    h_a = rgba_a.shape[0]
    dummies = cut_bands(rgba_a, 0, h_a, [190, 354, 525])[:4] if False else cut_bands(rgba_a[:, :710], 0, h_a, [190, 354, 525])
    idles = cut_bands(rgba_a[:, 715:], 0, h_a, [967 - 715, 1147 - 715, 1336 - 715])
    print('dummies', len(dummies), 'idles', len(idles))

    # ── 준비/타격 (위 줄 / 아래 줄) ──
    print('removing background: windup/strike ...')
    bm2 = background_mask(b)
    rgba_b = to_rgba(b, bm2)
    windups = cut_bands(rgba_b, 0, 548, [406, 735, 1092])
    strikes = cut_bands(rgba_b, 548, 1024, [435, 763, 1131])
    print('windups', len(windups), 'strikes', len(strikes))

    meta = {}
    d0, _ = dummies[0]
    save_png(d0, 'dummy.png')
    meta['dummy'] = {'w': int(d0.shape[1]), 'h': int(d0.shape[0])}

    def feet(arr, kind):
        """발 위치: 아래쪽 15%에서 어두운(장화) 픽셀의 가운데 x와 맨 아래 y. 칼끝·불꽃이 있는 타격 자세는 오른쪽 20%를 뺀다."""
        a = arr[..., 3] > 0
        lum = arr[..., :3].astype(int).sum(axis=2) / 3
        h, w = a.shape
        ys, xs = np.nonzero(a)
        top, bot = ys.min(), ys.max()
        band = np.zeros_like(a)
        band[int(bot - (bot - top) * 0.15): bot + 1, :] = True
        if kind == 'strike':
            band[:, int(w * 0.8):] = False
        m = a & band & (lum < 135)
        yy, xx = np.nonzero(m)
        return float((xx.min() + xx.max()) / 2), float(yy.max())

    for i in range(4):
        h_strike = None
        for kind, group in (('strike', strikes), ('idle', idles), ('windup', windups)):
            arr, box = group[i]
            name = f'c{i}_{kind}.png'
            save_png(arr, name)
            fx, fy = feet(arr, kind)
            meta[name] = {'w': int(arr.shape[1]), 'h': int(arr.shape[0]), 'footX': fx, 'footY': fy}
            if kind == 'windup':
                # 칼끝(가장 위쪽 픽셀들의 가운데) — 힘 모으는 빛을 여기에 그린다
                a_ = arr[..., 3] > 0
                ys_, xs_ = np.nonzero(a_)
                top = ys_.min()
                sel = ys_ <= top + 6
                meta[name]['tipX'] = float(np.median(xs_[sel]))
                meta[name]['tipY'] = float(top + 6)
            if kind == 'strike':
                h_strike = fy
            if kind == 'idle':
                # 기본 자세는 그림 비율이 달라서, 쭈그린 타격 자세보다 12% 크게 맞춘다
                meta[name]['scale'] = round(1.12 * h_strike / fy, 3)
            else:
                meta[name]['scale'] = 1.0
    with open(os.path.join(OUT, 'art.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=1)

    if sheet:
        # 확인용: 연두색 바탕에 모두 올려서 본다
        W = 1800
        canvas = Image.new('RGBA', (W, 1500), (60, 200, 90, 255))
        x, y, rowh = 10, 10, 0
        for name in sorted(os.listdir(OUT)):
            if not name.endswith('.png') or name == 'bg.png':
                continue
            im = Image.open(os.path.join(OUT, name))
            if x + im.width > W:
                x, y, rowh = 10, y + rowh + 10, 0
            canvas.alpha_composite(im, (x, y))
            x += im.width + 10
            rowh = max(rowh, im.height)
        canvas.convert('RGB').save(os.path.join(SRC, '_check_sheet.png'))
    print('done ->', OUT)


if __name__ == '__main__':
    main()
