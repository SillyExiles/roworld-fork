"""Preview of MapSurface.paint_terrain (Luau) in Python, same integer logic: renders a map module to PNG."""
import base64
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/home/claude/tools/pyshim")
import zstandard  # noqa: E402


def h32(x, y, s):
    # same as Luau: bit32 arithmetic
    v = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    v = v ^ (v >> 16)
    return v


def vnoise(x, y, cell, s):
    gx, gy = x // cell, y // cell
    fx = (x % cell) / cell
    fy = (y % cell) / cell
    a = (h32(gx, gy, s) & 0xFFFF) / 65535
    b = (h32(gx + 1, gy, s) & 0xFFFF) / 65535
    c = (h32(gx, gy + 1, s) & 0xFFFF) / 65535
    d = (h32(gx + 1, gy + 1, s) & 0xFFFF) / 65535
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    top = a + (b - a) * fx
    bot = c + (d - c) * fx
    return top + (bot - top) * fy


def clamp(v):
    return max(0, min(255, int(v)))


def paint(tb, W, H, lat_top, lat_bot):
    out = np.zeros((H, W, 3), np.uint8)
    for y in range(H):
        lat = lat_top + (lat_bot - lat_top) * (y + 0.5) / H if lat_top is not None else 0.0
        alat = abs(lat)
        for x in range(W):
            b = tb[y * W + x]
            hv = h32(x, y, 1)
            r01 = (hv & 0xFFFF) / 65535
            land = b >= 128
            shore = b & 64
            mag = b & 31
            if land and mag == 31 and not (b & 32):
                c = (0x3C, 0x3C, 0x3C)
            elif land:
                arid = b & 32
                # NW light: compare with the tile up-left
                nb = tb[(y - 1) * W + (x - 1)] if x > 0 and y > 0 else b
                nmag = (nb & 31) if nb >= 128 else 0
                light = 0
                if mag >= 10:
                    if nmag < mag - 1:
                        light = 1
                    elif nmag > mag + 1:
                        light = -1
                cold = alat > 64
                frozen = alat > 71
                if shore and not frozen:
                    c = (0xCC, 0xCB, 0x9E) if not cold else (0xC4, 0xC6, 0xB4)
                elif frozen or (mag >= 26):
                    c = (0xF2, 0xF4, 0xF6) if r01 > 0.12 else (0xDD, 0xE6, 0xEE)
                    if light < 0:
                        c = (0xD4, 0xDE, 0xE8)
                elif mag >= 20:
                    k = mag // 2
                    c = (0xE6 + k - 30, 0xE6 + k - 32, 0xE6 + k - 36) if not arid else (0xDE, 0xCF, 0xB4)
                    if light > 0:
                        c = tuple(clamp(v + 14) for v in c)
                    elif light < 0:
                        c = tuple(clamp(v - 22) for v in c)
                elif mag >= 10:
                    m = mag - 10
                    c = (0xDC + 2 * m, 0xCB + 2 * m, 0x9E + 2 * m) if not arid else (0xDE + m, 0xC0 + m, 0x8A + m)
                    if cold:
                        c = (0xC9, 0xCC, 0xB2)
                    if light > 0:
                        c = tuple(clamp(v + 10) for v in c)
                    elif light < 0:
                        c = tuple(clamp(v - 16) for v in c)
                elif cold:
                    c = (0xC8, 0xD3, 0xB0) if r01 > 0.2 else (0xB8, 0xC6, 0xA0)
                elif arid:
                    steppe = alat > 42
                    if steppe:
                        c = (0xD2, 0xD5, 0x98) if r01 > 0.1 else (0xC4, 0xC9, 0x8A)
                    else:
                        c = (0xE6, 0xD6, 0x9E)
                        dune = ((x + (y // 2) * 3) // 3 + (h32(x // 9, y // 5, 3) & 7)) % 7 == 0
                        if dune:
                            c = (0xD8, 0xC4, 0x88)
                        elif r01 < 0.05:
                            c = (0xEE, 0xE2, 0xB2)
                else:
                    n = vnoise(x, y, 14, 2) * 0.7 + vnoise(x, y, 5, 4) * 0.3
                    if alat > 50:
                        n += 0.12  # taiga
                    edge = 0.58 < n <= 0.62 and (x + y) % 2 == 0
                    if n > 0.62 or edge:
                        dense = n > 0.74
                        c = (0xA4, 0xCD, 0x78) if not dense else (0x96, 0xC2, 0x6C)
                        if r01 < 0.33:
                            c = (0x8E, 0xBB, 0x66) if not dense else (0x80, 0xAE, 0x5C)
                        elif r01 > 0.94:
                            c = (0xB4, 0xD8, 0x88)
                    else:
                        c = (0xBE, 0xDC - 2 * mag, 0x8A)
                        if r01 < 0.04:
                            c = (0xC8, 0xE4, 0x96)
            else:
                ocean = b & 32
                if shore:
                    c = (126, 170, 203)
                elif not ocean:
                    c = (0x55, 0x96, 0xC6)
                else:
                    if mag <= 1:
                        c = (0x5B, 0x9A, 0xC6)
                    elif mag <= 3:
                        c = (0x50, 0x8F, 0xBE)
                    else:
                        mm = min(mag, 12)
                        c = (0x47 - mm + 4, 0x85 - mm + 4, 0xB5 - mm + 4)
                        if mag >= 4 and (h32(x // 3, y, 5) & 0x3FF) < 3:
                            c = (0x62, 0x9E, 0xCA)
            out[y, x] = c
    return out


def main():
    path, png = sys.argv[1], sys.argv[2]
    crop = [int(v) for v in sys.argv[3].split(",")] if len(sys.argv) > 3 else None
    s = open(path).read()
    W = int(re.search(r"\bwidth = (\d+)", s).group(1))
    H = int(re.search(r"\bheight = (\d+)", s).group(1))
    lt = float(re.search(r"\blat_top = ([-\d.]+)", s).group(1))
    lb = float(re.search(r"\blat_bottom = ([-\d.]+)", s).group(1))
    t = re.search(r'\bterrain = "([^"]+)"', s).group(1)
    tb = zstandard.ZstdDecompressor().decompress(base64.b64decode(t), W * H)
    img = paint(tb, W, H, lt, lb)
    im = Image.fromarray(img)
    if crop:
        im = im.crop(crop).resize(((crop[2] - crop[0]) * 3, (crop[3] - crop[1]) * 3), Image.NEAREST)
    im.save(png)


main()
