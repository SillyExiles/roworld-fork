"""Empires Front ship sprites: side-view pixel art, 24 x 24, grey-scale (tinted by the owner's colour in
game). Tones: outline 70, hull 150, deck/dark wood 110, sail 255, mast/oars 95, trim 205.
Writes a preview sheet and Luau data (base64 of RGBA bytes) for client/Map/ShipArt."""
import base64, sys
from PIL import Image

N = 24
O, HULL, DARK, SAIL, MAST, TRIM = 70, 150, 110, 255, 95, 205


class Spr:
    def __init__(self):
        self.px = {}

    def put(self, x, y, v):
        if 0 <= x < N and 0 <= y < N:
            self.px[(x, y)] = v

    def rect(self, x0, y0, x1, y1, v):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, v)

    def outline(self):
        """Dark 1-px outline around every drawn pixel (where empty)."""
        add = {}
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in self.px and 0 <= q[0] < N and 0 <= q[1] < N:
                    add[q] = O
        self.px.update(add)

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for (x, y), v in self.px.items():
            im.putpixel((x, y), (v, v, v, 255))
        return im


def hull(s, x0, x1, top, depth, bow=3, stern=2, ram=False, high_stern=0):
    """A hull from x0 to x1 (deck at `top`), curving up at both ends."""
    for i in range(depth):
        y = top + i
        a = x0 + min(stern, i + 1) - 1 + (1 if i == depth - 1 else 0)
        b = x1 - min(bow, i + 1) + 1 - (1 if i == depth - 1 else 0)
        for x in range(a, b + 1):
            s.put(x, y, HULL if i > 0 else TRIM)
    # stripe
    for x in range(x0 + 2, x1 - 1):
        s.put(x, top + 1, DARK)
    if ram:
        s.put(x1 + 1, top + depth - 2, HULL)
        s.put(x1 + 2, top + depth - 2, HULL)
    for k in range(high_stern):
        for x in range(x0, x0 + 4 - k // 2):
            s.put(x, top - 1 - k, HULL if k < high_stern - 1 else TRIM)


def mast(s, x, y0, y1):
    for y in range(y0, y1 + 1):
        s.put(x, y, MAST)


def square_sail(s, xc, y0, h, w, belly=1):
    for i in range(h):
        bw = w + (belly if 0 < i < h - 1 else 0)
        s.rect(xc - bw // 2, y0 + i, xc + (bw - 1) // 2, y0 + i, SAIL)


def lateen(s, x0, y0, h):
    for i in range(h):
        s.rect(x0, y0 + i, x0 + i, y0 + i, SAIL)


def junk_sail(s, xc, y0, h, w):
    for i in range(h):
        s.rect(xc - w // 2, y0 + i, xc + w // 2 - (1 if i < 2 else 0), y0 + i, DARK if i % 3 == 2 else SAIL)


def oars(s, x0, x1, y, step=2, length=3):
    for x in range(x0, x1 + 1, step):
        for k in range(length):
            s.put(x - k // 2, y + k, MAST)


def flag(s, x, y):
    s.put(x, y, TRIM)
    s.put(x + 1, y, TRIM)
    s.put(x + 1, y + 1, TRIM)


# ---- antiquity (Rome, Persia) ----
def ancient_war():
    s = Spr()
    hull(s, 2, 20, 14, 4, bow=3, stern=4, ram=True)
    mast(s, 11, 3, 13)
    square_sail(s, 11, 4, 7, 9)
    oars(s, 4, 18, 18, step=2, length=3)
    s.rect(3, 12, 5, 13, HULL)    # curled stern post
    s.put(3, 11, TRIM)
    flag(s, 11, 2)
    s.outline()
    return s


def ancient_trade():
    s = Spr()
    hull(s, 3, 20, 13, 6, bow=4, stern=4)
    s.rect(3, 10, 4, 12, HULL)
    s.put(4, 9, TRIM)               # swan-neck stern
    s.put(5, 8, TRIM)
    mast(s, 12, 2, 12)
    square_sail(s, 12, 3, 8, 11, belly=2)
    s.rect(17, 11, 19, 12, MAST)    # bowsprit
    s.outline()
    return s


def ancient_transport():
    s = Spr()
    hull(s, 4, 19, 15, 4, bow=3, stern=3)
    mast(s, 11, 6, 14)
    square_sail(s, 11, 7, 5, 7)
    oars(s, 6, 17, 19, step=3, length=3)
    for x in (7, 10, 13, 16):     # troops' shields
        s.put(x, 14, TRIM)
    s.outline()
    return s


# ---- Ming China ----
def junk_war():
    s = Spr()
    hull(s, 1, 21, 14, 5, bow=2, stern=2, high_stern=3)
    mast(s, 9, 2, 13)
    junk_sail(s, 9, 3, 9, 7)
    mast(s, 16, 5, 13)
    junk_sail(s, 16, 6, 7, 5)
    mast(s, 4, 7, 10)
    for x in (5, 9, 13, 17):      # gun ports
        s.put(x, 16, O)
    flag(s, 9, 1)
    s.outline()
    return s


def junk_trade():
    s = Spr()
    hull(s, 2, 21, 14, 6, bow=2, stern=2, high_stern=2)
    mast(s, 11, 3, 13)
    junk_sail(s, 11, 4, 9, 9)
    mast(s, 18, 7, 13)
    junk_sail(s, 18, 8, 5, 3)
    s.rect(5, 12, 7, 13, DARK)    # cargo
    s.outline()
    return s


def junk_transport():
    s = Spr()
    hull(s, 4, 19, 15, 4, bow=2, stern=2, high_stern=2)
    mast(s, 12, 6, 14)
    junk_sail(s, 12, 7, 7, 7)
    for x in (7, 9, 15, 17):
        s.put(x, 14, TRIM)
    s.outline()
    return s


# ---- Age of Sail (Spain) ----
def galleon():
    s = Spr()
    hull(s, 1, 21, 14, 6, bow=3, stern=1, high_stern=4)
    for x, top, w in ((7, 4, 5), (13, 2, 5), (19, 6, 3)):
        mast(s, x, top, 13)
        square_sail(s, x, top + 1, 3, w, belly=0)
        square_sail(s, x, top + 5, 4, w, belly=1)
    mast(s, 2, 7, 13)
    lateen(s, 1, 8, 3)
    s.rect(20, 12, 23, 12, MAST)  # bowsprit
    for x in (6, 9, 12, 15, 18):  # gun ports
        s.put(x, 17, O)
    flag(s, 14, 1)
    s.outline()
    return s


def caravel():
    s = Spr()
    hull(s, 3, 20, 14, 5, bow=3, stern=1, high_stern=2)
    mast(s, 10, 3, 13)
    lateen(s, 6, 4, 9)
    mast(s, 16, 6, 13)
    lateen(s, 13, 7, 6)
    s.rect(18, 12, 21, 12, MAST)
    s.outline()
    return s


def carrack():
    s = Spr()
    hull(s, 3, 20, 14, 5, bow=3, stern=1, high_stern=3)
    mast(s, 12, 4, 13)
    square_sail(s, 12, 5, 6, 9, belly=2)
    mast(s, 6, 8, 13)
    lateen(s, 4, 9, 4)
    for x in (9, 12, 15):
        s.put(x, 13, TRIM)
    s.outline()
    return s


SETS = {
    "ancient": {"warship": ancient_war, "trade": ancient_trade, "transport": ancient_transport},
    "junk": {"warship": junk_war, "trade": junk_trade, "transport": junk_transport},
    "sail": {"warship": galleon, "trade": caravel, "transport": carrack},
}


def main(out):
    sheet = Image.new("RGBA", (N * 3 * 3 + 16, N + 4), (60, 120, 180, 255))
    lines = ["-- GENERATED by tools/make_ships.py: ship sprites (grey-scale RGBA, %d x %d, base64), by era style." % (N, N),
             "return {", "\tsize = %d," % N]
    i = 0
    for style, ships in SETS.items():
        lines.append("\t%s = {" % style)
        for kind, fn in ships.items():
            im = fn().image()
            # tint preview with a red owner colour
            tinted = Image.new("RGBA", (N, N))
            for y in range(N):
                for x in range(N):
                    r, g, b, a = im.getpixel((x, y))
                    tinted.putpixel((x, y), (int(r * 0.9), int(g * 0.35), int(b * 0.3), a))
            sheet.alpha_composite(tinted, (i * N + (i // 3) * 8, 2))
            i += 1
            lines.append('\t\t%s = "%s",' % (kind, base64.b64encode(im.tobytes()).decode()))
        lines.append("\t},")
    lines.append("}")
    open(out, "w").write("\n".join(lines) + "\n")
    sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save("/home/claude/art3/ships.png")


main(sys.argv[1])
