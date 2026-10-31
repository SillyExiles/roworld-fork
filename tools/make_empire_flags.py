"""Empires Front: the Empire Shop's flags — pixel-art flags (18 x 12) that tile over a nation's land as a
territory skin (Data/Cosmetics multi-colour skins). Writes src/shared/Data/EmpireFlags.luau and a preview
sheet. Historical banners are simplified original pixel drawings; national flags are public-domain designs.

usage: python3 tools/make_empire_flags.py src/shared/Data/EmpireFlags.luau preview.png
"""
import math
import sys

W, H = 18, 12

C = {
    "red": 0xC8102E, "crimson": 0x9B111E, "darkred": 0x7A0E14, "white": 0xF4F4F0, "black": 0x1A1A1A,
    "gold": 0xF2B705, "yellow": 0xFFD200, "blue": 0x0038A8, "navy": 0x012169, "sky": 0x75AADB,
    "green": 0x009246, "darkgreen": 0x00602A, "orange": 0xFF8C00, "purple": 0x5B2A86, "brown": 0x6B3E1E,
    "teal": 0x00838F, "grey": 0x8A8D91, "tan": 0xD8B878, "pink": 0xE58FAC, "saffron": 0xFF9933,
    "lightblue": 0x5BA4E6, "maroon": 0x6E1423, "turquoise": 0x40C4C0, "indigo": 0x2E3A87,
}


class Flag:
    def __init__(self):
        self.px = [["white"] * W for _ in range(H)]

    def fill(self, c):
        for y in range(H):
            for x in range(W):
                self.px[y][x] = c
        return self

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):  # inclusive
        for y in range(max(0, y0), min(H - 1, y1) + 1):
            for x in range(max(0, x0), min(W - 1, x1) + 1):
                self.px[y][x] = c
        return self

    def hstripes(self, *cs):
        n = len(cs)
        for y in range(H):
            self.rect(0, y, W - 1, y, cs[min(n - 1, y * n // H)])
        return self

    def vstripes(self, *cs):
        n = len(cs)
        for x in range(W):
            self.rect(x, 0, x, H - 1, cs[min(n - 1, x * n // W)])
        return self

    def disc(self, cx, cy, r, c):
        for y in range(H):
            for x in range(W):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.px[y][x] = c
        return self

    def ring(self, cx, cy, r, w, c):
        for y in range(H):
            for x in range(W):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if r - w <= d <= r:
                    self.px[y][x] = c
        return self

    def crescent(self, cx, cy, r, c, off=1.2):
        for y in range(H):
            for x in range(W):
                inside = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r
                cut = (x + 0.5 - cx - off) ** 2 + (y + 0.5 - cy) ** 2 <= (r * 0.8) ** 2
                if inside and not cut:
                    self.px[y][x] = c
        return self

    def star(self, cx, cy, c, big=False):
        pts = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
        if big:
            pts += [(0, -2), (-2, 0), (2, 0), (-1, 1), (1, 1), (-1, 2), (1, 2)]
        for dx, dy in pts:
            self.set(cx + dx, cy + dy, c)
        return self

    def cross(self, cx, cy, t, c):  # nordic/greek cross through (cx, cy), thickness t
        self.rect(0, cy, W - 1, cy + t - 1, c)
        self.rect(cx, 0, cx + t - 1, H - 1, c)
        return self

    def saltire(self, t, c):
        for y in range(H):
            for x in range(W):
                u = x / (W - 1)
                v = y / (H - 1)
                if abs(u - v) * (H - 1) < t or abs(u - (1 - v)) * (H - 1) < t:
                    self.px[y][x] = c
        return self

    def tri(self, depth, c):  # hoist triangle
        for y in range(H):
            reach = depth * (1 - abs(y + 0.5 - H / 2) / (H / 2))
            for x in range(W):
                if x + 0.5 <= reach:
                    self.px[y][x] = c
        return self

    def shape(self, x0, y0, rows, cmap):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in cmap:
                    self.set(x0 + i, y0 + j, cmap[ch])
        return self


# Small motifs (pixel rows): 'x' = the motif colour, 'o' = a second colour
EAGLE = [
    "x..x..x",
    "xx.x.xx",
    "xxxxxxx",
    ".xxxxx.",
    "..xxx..",
    "..x.x..",
]
DOUBLE_EAGLE = [
    "x.x...x.x",
    "xxx...xxx",
    ".xxx.xxx.",
    "xxxxxxxxx",
    "..xxxxx..",
    "...xxx...",
    "..x.x.x..",
]
LION = [
    ".xx.....",
    "xxxx..x.",
    "xxxxxxx.",
    ".xxxxxx.",
    ".x.x.x.x",
]
FLEUR = [
    "..x..",
    ".xxx.",
    "x.x.x",
    "xxxxx",
    "..x..",
    ".x.x.",
]
SUN16 = [
    "x..x..x",
    ".x.x.x.",
    "..xxx..",
    "xxxxxxx",
    "..xxx..",
    ".x.x.x.",
    "x..x..x",
]
OWL = [
    "x.....x",
    "xxxxxxx",
    "xo.x.ox",
    "xxxxxxx",
    ".xxxxx.",
    ".xx.xx.",
]
LAMBDA = [
    "...x...",
    "..x.x..",
    "..x.x..",
    ".x...x.",
    ".x...x.",
    "x.....x",
]
DRAGON = [
    ".xx..........",
    "xxox...xx....",
    ".xxxx.xxxx...",
    "...xxxx..xx.x",
    "....xx....xxx",
]
RAVEN = [
    "...xx...",
    "..xxxx..",
    "xxxxxxx.",
    ".xxxxxxx",
    "..xx.x..",
]
HOLLYHOCK = [
    "..xxx..",
    ".x.x.x.",
    "xx.x.xx",
    "xxxxxxx",
    "x.xxx.x",
    ".x.x.x.",
    "..xxx..",
]
TANIT = [
    "..x..",
    ".xxx.",
    "..x..",
    "xxxxx",
    ".xxx.",
    "xxxxx",
]
CHRYS = [  # 16-petal chrysanthemum (Imperial Japan)
    ".x.x.x.",
    "xxxxxxx",
    ".xxoxx.",
    "xxooxxx",
    ".xxoxx.",
    "xxxxxxx",
    ".x.x.x.",
]

FLAGS = []


def add(key, name, tier, f, robux=False, era="", sub=False):
    FLAGS.append({"key": key, "name": name, "tier": tier, "flag": f, "robux": robux, "era": era, "sub": sub})


def F():
    return Flag()


# ---------------------------------------------------------------- Robux (the Robux shop)
f = F().fill("navy").rect(0, 0, W - 1, 0, "gold").rect(0, H - 1, W - 1, H - 1, "gold")
f.disc(9, 3.2, 1.6, "gold").shape(5, 5, EAGLE, {"x": "white"})
add("mongol", "Mongol Empire", "legendary", f, robux=True, era="mongol")

f = F().fill("red").crescent(7.5, 6, 3.6, "white", off=1.3).star(11, 6, "white", big=True)
add("ottoman", "Ottoman Empire", "legendary", f, robux=True, era="ottoman")

f = F().fill("darkgreen").shape(3, 1, [
    "......xx......",
    "....xxxxxx....",
    "..xxxxxxxxxx..",
    "xxxxxxxxxxxxxx",
    "xxxxxxxxxxxxxx",
    "xxxxxxxxxxxxxx",
    "xxxxxxxxxxxxxx",
    "..xxxxxxxxxx..",
    "....xxxxxx....",
    "......xx......",
], {"x": "yellow"})
f.shape(7, 2, [".rr.", "rrrr", "bbbb", "bggb", "bggb", ".bb."], {"r": "red", "b": "darkgreen", "g": "gold"})
add("brazil_imp", "Empire of Brazil", "legendary", f, robux=True)

f = F().vstripes("gold", "white")
f.shape(10, 2, [
    "..yy..",
    ".yyyy.",
    "..yy..",
    "x....o",
    ".x..o.",
    "..xo..",
    "..ox..",
    ".o..x.",
    "o....x",
], {"y": "gold", "x": "gold", "o": "grey"})
add("papal", "Papal States", "legendary", f, robux=True)


# ---------------------------------------------------------------- empires of the maps
f = F().fill("crimson").rect(0, 0, W - 1, 1, "gold").rect(0, H - 2, W - 1, H - 1, "gold")
f.shape(5, 3, EAGLE + [], {"x": "gold"}).rect(12, 4, 13, 8, "gold")
add("rome", "Roman Empire (SPQR)", "legendary", f, robux=True, era="rome")

f = F().fill("crimson").shape(4, 2, [
    "x.......x",
    "xx.....xx",
    "xxx.x.xxx",
    ".xxxxxxx.",
    "..xxxxx..",
    "...xxx...",
    "...x.x...",
    "..xx.xx..",
], {"x": "gold"})
add("persia", "Achaemenid Persia", "epic", f, era="persia")

f = F().fill("purple").rect(0, 0, W - 1, H - 1, "purple").shape(6, 2, [
    "..x..",
    ".xxx.",
    "xxxxx",
    ".xxx.",
    "..x..",
], {"x": "gold"}).rect(0, H - 3, W - 1, H - 3, "red").rect(0, H - 2, W - 1, H - 1, "yellow")
add("sasanian", "Derafsh Kaviani", "rare", f, era="persia")

f = F().fill("yellow").shape(2, 4, DRAGON, {"x": "blue", "o": "red"}).disc(15, 3, 1.3, "red")
add("qing", "Qing Dragon", "legendary", f, era="china")

f = F().fill("red").disc(5, 6, 2.6, "gold").crescent(13, 6, 2.6, "white", off=1.0)
add("ming", "Ming Sun and Moon", "epic", f, era="china")

f = F().vstripes("red", "white").rect(0, 4, W - 1, 7, "red")
f = F().fill("white")
for i, c in enumerate(["red", "orange", "yellow", "green", "sky", "blue", "purple"]):
    f.rect(0, int(i * H / 7), W - 1, int((i + 1) * H / 7), c)
# (v10: no flag for the Inca and Aztec empires) add("inca")

f = F().fill("white").rect(0, 0, W - 1, 1, "green").rect(0, H - 2, W - 1, H - 1, "green")
f.shape(6, 3, ["..xx..", ".xxxx.", "xxooxx", "..oo..", ".gggg.", "gg..gg"], {"x": "brown", "o": "darkgreen", "g": "green"})
# (v10: no flag for the Inca and Aztec empires) add("aztec")

f = F().fill("gold").rect(0, 0, W - 1, 0, "darkgreen").rect(0, H - 1, W - 1, H - 1, "darkgreen")
f.shape(5, 3, LION, {"x": "brown"}).rect(14, 2, 15, 9, "darkgreen")
add("mali", "Mali Empire", "rare", f, era="mali")

f = F().hstripes("black", "gold", "white")
f.shape(5, 2, DOUBLE_EAGLE, {"x": "black"}) if False else None
add("russia_imp", "Russian Empire", "rare", f, era="russia")

f = F().fill("gold").shape(4, 2, DOUBLE_EAGLE, {"x": "black"})
add("hre", "Holy Roman Empire", "epic", f)

f = F().fill("navy").saltire(1.0, "white")
f.rect(0, 4, W - 1, 7, "white").rect(7, 0, 10, H - 1, "white").rect(0, 5, W - 1, 6, "red").rect(8, 0, 9, H - 1, "red")
add("britain", "British Empire", "epic", f, era="britain")

f = F().fill("red").cross(8, 5, 2, "gold")
for x0, y0 in ((2, 1), (12, 1), (2, 8), (12, 8)):
    f.shape(x0, y0, ["xxx", "x.x", "xxx"], {"x": "gold"})
add("byzantine", "Byzantine Empire", "legendary", f)

f = F().fill("white").saltire(0.7, "red")
add("spain_imp", "Spanish Empire", "legendary", f, robux=True)

f = F().fill("white").shape(6, 3, FLEUR, {"x": "gold"}).shape(1, 1, ["x"], {"x": "gold"})
f = F().fill("blue")
for x0, y0 in ((2, 2), (11, 2), (6, 6)):
    f.shape(x0, y0, FLEUR, {"x": "gold"})
add("france_roy", "Royal France", "epic", f)

f = F().vstripes("blue", "white", "red").shape(6, 3, EAGLE, {"x": "gold"})
add("napoleon", "First French Empire", "epic", f)

f = F().fill("white").rect(0, 0, W - 1, 1, "black").rect(0, H - 2, W - 1, H - 1, "black").shape(5, 3, EAGLE, {"x": "black"})
add("prussia", "Kingdom of Prussia", "rare", f)

f = F().hstripes("black", "gold")

f = F().fill("crimson").shape(5, 3, LION, {"x": "gold"}).rect(0, H - 2, W - 1, H - 1, "gold")
add("venice", "Republic of Venice", "rare", f)

f = F().fill("purple").shape(6, 3, TANIT, {"x": "gold"})
add("carthage", "Carthage", "rare", f)

f = F().fill("gold").shape(5, 2, [
    "...x...",
    "..xxx..",
    ".xxoxx.",
    "xxooxxx",
    ".xxoxx.",
    "..xxx..",
    "...x...",
    "..xxx..",
], {"x": "blue", "o": "white"})
add("egypt_anc", "Ancient Egypt", "epic", f)

f = F().fill("red").shape(5, 2, SUN16, {"x": "gold"})
add("macedon", "Macedon (Vergina Sun)", "epic", f, era="greece")

f = F().fill("sky").shape(5, 3, OWL, {"x": "white", "o": "gold"})
add("athens", "Athens", "rare", f, era="greece")

f = F().fill("crimson").shape(5, 3, LAMBDA, {"x": "gold"})
add("sparta", "Sparta", "rare", f, era="greece")


f = F().fill("white").shape(5, 2, HOLLYHOCK, {"x": "black"})
add("tokugawa", "Tokugawa Shogunate", "rare", f, era="japan")

f = F().fill("crimson").shape(5, 2, CHRYS, {"x": "gold", "o": "crimson"})
add("chrysanthemum", "Chrysanthemum Throne", "legendary", f, era="japan")

f = F().fill("white").shape(5, 3, RAVEN, {"x": "black"}).rect(0, H - 1, W - 1, H - 1, "red")
add("norse", "Norse Raven Banner", "rare", f)

f = F().fill("gold").shape(6, 3, ["x...x", "x...x", "xxxxx", "..x..", "..x..", ".xxx."], {"x": "red"})
add("golden_horde", "Golden Horde", "rare", f)

f = F().fill("black")
for cx, cy in ((6, 4), (12, 4), (9, 8)):
    f.ring(cx, cy, 2.0, 0.9, "gold")
add("timurid", "Timurid Empire", "rare", f)

f = F().fill("darkgreen").shape(5, 2, SUN16, {"x": "gold"})
add("mughal", "Mughal Empire", "epic", f)

f = F().hstripes("green", "yellow", "red").disc(9, 6, 2.6, "blue").star(9, 6, "yellow")
add("ethiopia", "Ethiopian Empire", "rare", f)

f = F().fill("white").disc(9, 6, 3.2, "red").rect(6, 6, 12, 9, "blue")
f.disc(9, 6, 3.2, "red")
for y in range(H):
    for x in range(W):
        if (x + 0.5 - 9) ** 2 + (y + 0.5 - 6) ** 2 <= 3.2 ** 2 and y >= 6:
            f.set(x, y, "blue")
f.rect(1, 1, 3, 1, "black").rect(14, 10, 16, 10, "black").rect(14, 1, 16, 1, "black").rect(1, 10, 3, 10, "black")
add("joseon", "Joseon Korea", "rare", f)

# ---------------------------------------------------------------- nations (public-domain national flags)
add("brazil", "Brazil", "common", (lambda f: (f.fill("green").shape(3, 1, [
    "......xx......",
    "....xxxxxx....",
    "..xxxxxxxxxx..",
    "xxxxxbbbbxxxxx",
    "xxxxbbbbbbxxxx",
    "xxxxbbbbbbxxxx",
    "xxxxxbbbbxxxxx",
    "..xxxxxxxxxx..",
    "....xxxxxx....",
    "......xx......",
], {"x": "yellow", "b": "blue"}), f)[1])(F()))
add("portugal", "Portugal", "common", F().vstripes("darkgreen", "red", "red").disc(7, 6, 2.2, "gold").disc(7, 6, 1.2, "red"))
add("italy", "Italy", "common", F().vstripes("green", "white", "red"))
add("france", "France", "common", F().vstripes("blue", "white", "red"))
add("germany", "Germany", "common", F().hstripes("black", "red", "gold"))
add("japan", "Japan", "common", F().fill("white").disc(9, 6, 3.3, "red"))
add("greece", "Greece", "common", (lambda f: f.rect(0, 0, 7, 6, "blue").rect(3, 0, 4, 6, "white").rect(0, 3, 7, 3, "white"))(
    F().fill("white").hstripes("blue", "white", "blue", "white", "blue", "white", "blue", "white", "blue")))
add("turkey", "Turkey", "common", F().fill("red").crescent(7, 6, 3.4, "white", off=1.1).star(11, 6, "white"))
add("usa", "United States", "rare", (lambda f: [f.rect(0, 0, 7, 6, "navy")] and [f.set(x, y, "white") for y in range(1, 6, 2) for x in range(1, 7, 2)] and f)(
    F().hstripes(*(["red", "white"] * 6 + ["red"]))))
add("mexico", "Mexico", "common", F().vstripes("green", "white", "red").shape(7, 4, ["x..x", "xxxx", ".oo.", "o..o"], {"x": "brown", "o": "darkgreen"}))
add("argentina", "Argentina", "common", F().hstripes("sky", "white", "sky").disc(9, 6, 1.4, "gold"))
add("spain", "Spain", "common", F().hstripes("red", "yellow", "yellow", "red").rect(4, 4, 5, 7, "crimson"))
add("india", "India", "common", F().hstripes("saffron", "white", "darkgreen").ring(9, 6, 1.8, 0.8, "navy"))
add("canada", "Canada", "rare", F().vstripes("red", "white", "white", "red").shape(6, 2, [
    "...x...",
    ".x.x.x.",
    "xxxxxxx",
    ".xxxxx.",
    "..xxx..",
    "...x...",
    "...x...",
], {"x": "red"}))
add("sweden", "Sweden", "common", F().fill("blue").cross(5, 5, 2, "yellow"))
add("norway", "Norway", "common", F().fill("red").cross(5, 4, 4, "white").cross(6, 5, 2, "navy"))
add("poland", "Poland", "common", F().hstripes("white", "red"))
add("ukraine", "Ukraine", "common", F().hstripes("blue", "yellow"))
add("colombia", "Colombia", "common", (lambda f: f.rect(0, 0, W - 1, 5, "yellow").rect(0, 6, W - 1, 8, "blue").rect(0, 9, W - 1, H - 1, "red"))(F()))
add("switzerland", "Switzerland", "common", F().fill("red").rect(7, 2, 10, 9, "white").rect(4, 4, 13, 7, "white"))

TIER_PRICE = {"common": 1500, "rare": 3000, "epic": 6000, "legendary": 12000}
ROBUX_PRICE = 149


def chars():
    return "123456789abcdefghijklmnopqrstuvwxyz"


def encode(f):
    """Rows of mask chars (+ a one-pixel gutter of the owner's fill, '.', right and bottom) and the palette."""
    used = []
    for row in f.px:
        for c in row:
            if c not in used:
                used.append(c)
    assert len(used) <= 35
    ch = chars()
    rows = []
    for row in f.px:
        rows.append("".join(ch[used.index(c)] for c in row) + ".")
    rows.append("." * (W + 1))
    return rows, [C[c] for c in used]


def main(out_luau, out_png=None):
    lines = [
        "--!strict",
        "-- GENERATED by tools/make_empire_flags.py — do not edit by hand.",
        "-- Empires Front: the Empire Shop's flags (Data/Cosmetics territory skins, several colours). Each",
        "-- tiles over its owner's land: an 18 x 12 pixel flag and a one-tile gutter of the owner's own colour.",
        "-- `stars`: its price in Stars (the shop); `robux` > 0: sold for Robux only (Data/Products ef_<key>);",
        "-- `subscriber`: never sold, the subscription's flag (Data/Subscription.SKINS).",
        "return {",
    ]
    for e in FLAGS:
        rows, cols = encode(e["flag"])
        price = 0 if (e["sub"] or e["robux"]) else TIER_PRICE[e["tier"]]
        lines.append("\t{")
        lines.append('\t\tkey = "%s",' % e["key"])
        lines.append('\t\tname = "%s",' % e["name"])
        lines.append('\t\ttier = "%s",' % e["tier"])
        lines.append('\t\tera = "%s",' % e["era"])
        lines.append("\t\tstars = %d," % price)
        lines.append("\t\trobux = %d," % (ROBUX_PRICE if e["robux"] else 0))
        if e["sub"]:
            lines.append("\t\tsubscriber = true,")
        lines.append("\t\tcolors = { %s }," % ", ".join("0x%06X" % c for c in cols))
        lines.append("\t\tmask = {")
        for r in rows:
            lines.append('\t\t\t"%s",' % r)
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    open(out_luau, "w").write("\n".join(lines) + "\n")
    print(len(FLAGS), "flags;", sum(1 for e in FLAGS if e["robux"]), "for Robux")
    if out_png:
        from PIL import Image, ImageDraw
        cols = 8
        cell = (W * 6 + 10, H * 6 + 24)
        rows_n = (len(FLAGS) + cols - 1) // cols
        im = Image.new("RGB", (cols * cell[0], rows_n * cell[1]), (24, 26, 36))
        d = ImageDraw.Draw(im)
        for i, e in enumerate(FLAGS):
            ox, oy = (i % cols) * cell[0] + 5, (i // cols) * cell[1] + 4
            for y in range(H):
                for x in range(W):
                    c = C[e["flag"].px[y][x]]
                    d.rectangle([ox + x * 6, oy + y * 6, ox + x * 6 + 5, oy + y * 6 + 5], fill=((c >> 16) & 255, (c >> 8) & 255, c & 255))
            d.text((ox, oy + H * 6 + 4), e["key"], fill=(220, 220, 220))
        im.save(out_png)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
