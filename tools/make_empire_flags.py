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

# ---------------------------------------------------------------- more flags (v10b)
add("netherlands", "Netherlands", "common", F().hstripes("red", "white", "blue"))
add("belgium", "Belgium", "common", F().vstripes("black", "yellow", "red"))
add("ireland", "Ireland", "common", F().vstripes("green", "white", "orange"))
add("austria", "Austria", "common", F().hstripes("red", "white", "red"))
add("hungary", "Hungary", "common", F().hstripes("red", "white", "green"))
add("romania", "Romania", "common", F().vstripes("blue", "yellow", "red"))
add("bulgaria", "Bulgaria", "common", F().hstripes("white", "green", "red"))
add("lithuania", "Lithuania", "common", F().hstripes("yellow", "green", "red"))
add("estonia", "Estonia", "common", F().hstripes("blue", "black", "white"))
add("denmark", "Denmark", "common", F().fill("red").cross(5, 5, 2, "white"))
add("finland", "Finland", "common", F().fill("white").cross(5, 4, 3, "navy"))
add("iceland", "Iceland", "rare", F().fill("blue").cross(5, 4, 4, "white").cross(6, 5, 2, "red"))
add("peru", "Peru", "common", F().vstripes("red", "white", "red"))
add("chile", "Chile", "rare", (lambda f: f.rect(0, 0, 6, 5, "blue").star(3, 2, "white"))(F().hstripes("white", "red")))
add("bolivia", "Bolivia", "common", F().hstripes("red", "yellow", "green"))
add("venezuela", "Venezuela", "rare", (lambda f: [f.set(x, 5, "white") for x in (6, 8, 10, 12)] and f)(F().hstripes("yellow", "blue", "red")))
add("philippines", "Philippines", "rare", F().hstripes("blue", "red").tri(9, "white").disc(3.2, 6, 1.4, "yellow"))
add("thailand", "Thailand", "common", (lambda f: f.rect(0, 4, W - 1, 7, "navy"))(F().hstripes("red", "white", "white", "white", "white", "red")))
add("vietnam_dv", "Dai Viet", "rare", F().fill("yellow").disc(9, 6, 3, "red"))
add("israel_kingdom", "Kingdom of Jerusalem", "epic", (lambda f: f.cross(8, 5, 2, "gold") and [f.shape(x, y, ["x.x", ".x.", "x.x"], {"x": "gold"}) for x, y in ((2, 1), (13, 1), (2, 8), (13, 8))] and f)(F().fill("white")))
add("templar", "Knights Templar", "epic", F().fill("white").rect(0, 0, W - 1, 5, "black").cross(8, 4, 2, "red"))
add("hospitaller", "Knights Hospitaller", "rare", F().fill("red").cross(8, 5, 2, "white"))
add("scotland", "Scotland", "rare", F().fill("blue").saltire(1.1, "white"))
add("wales_dragon", "Welsh Dragon", "epic", (lambda f: f.shape(3, 3, DRAGON, {"x": "red", "o": "red"}))(F().hstripes("white", "green")))
add("castile", "Kingdom of Castile", "epic", (lambda f: [f.shape(x, y, ["x.x.x", "xxxxx", ".xxx.", ".x.x."], {"x": "gold"}) for x, y in ((2, 2), (11, 7))] and [f.shape(x, y, ["xx..", "xxx.", ".xxx", "x.x."], {"x": "purple"}) for x, y in ((12, 1), (2, 7))] and f)(
    F().fill("white").rect(0, 0, 8, 5, "red").rect(9, 6, W - 1, H - 1, "red")))
add("aragon", "Crown of Aragon", "rare", F().vstripes("yellow", "red", "yellow", "red", "yellow", "red", "yellow", "red", "yellow"))
add("burgundy", "Duchy of Burgundy", "rare", F().fill("blue").vstripes("gold", "blue", "gold", "blue", "gold", "blue").rect(0, 0, W - 1, 1, "red").rect(0, H - 2, W - 1, H - 1, "red"))
add("polish_lith", "Polish-Lithuanian Commonwealth", "epic", (lambda f: f.shape(2, 3, EAGLE, {"x": "white"}).shape(11, 3, ["..x..", "xxxxx", "..xx.", ".xxxx", "x..x."], {"x": "white"}))(F().fill("red")))
add("teutonic", "Teutonic Order", "rare", F().fill("white").cross(8, 5, 2, "black"))
add("genoa", "Republic of Genoa", "rare", F().fill("white").cross(8, 5, 2, "red"))
add("kievan_rus", "Kievan Rus'", "rare", F().fill("red").shape(6, 2, ["x...x", "x.x.x", "xxxxx", "x.x.x", ".xxx.", "..x..", "..x.."], {"x": "gold"}))
add("songhai", "Songhai Empire", "rare", F().hstripes("green", "gold", "red").disc(9, 6, 2.2, "darkred"))
add("zulu", "Zulu Kingdom", "rare", F().fill("brown").shape(6, 2, ["...x..", "..xx..", ".xxxx.", "xxooxx", ".xxxx.", "..xx..", "...x.."], {"x": "white", "o": "black"}))
add("vijayanagara", "Vijayanagara", "rare", F().fill("red").shape(5, 2, SUN16, {"x": "gold"}))
add("champa", "Khmer Empire", "rare", F().fill("blue").rect(0, 3, W - 1, 8, "red").shape(6, 4, ["..x..", ".xxx.", "xx.xx", "xxxxx"], {"x": "white"}))

# ---------------------------------------------------------------- more flags (2026-11-06)
C.update({"kazblue": 0x00AFCA, "silver": 0xC0C4C8, "flesh": 0xE8B48A, "lapis": 0x1D3F9E})


def mirror(rows):
    return [r[::-1] for r in rows]


STAR5 = [
    "...x...",
    "...x...",
    "xxxxxxx",
    ".xxxxx.",
    "..xxx..",
    ".xx.xx.",
    "xx...xx",
]
LION_S = [  # a small lion passant
    ".xx...x",
    "xxxxxxx",
    "x.x.x.x",
]
RAMPANT = [  # a lion rampant
    "..xx...",
    ".xxx...",
    "..xxx.x",
    ".xxxxxx",
    "xxxxx..",
    "..xxx..",
    ".xx.xx.",
    "xx...xx",
]
GIGLIO = [  # the lily of Florence
    "...x...",
    "..xxx..",
    "x.xxx.x",
    "xx.x.xx",
    "xxxxxxx",
    "x..x..x",
    "..xxx..",
    ".x.x.x.",
]
D5 = ["..x..", ".xxx.", "xxxxx", ".xxx.", "..x.."]
COIN = [".xx.", "x..x", "x..x", ".xx."]
MOKKO = [
    "..xx.xx..",
    ".x..x..x.",
    ".x.....x.",
    "xx..x..xx",
    "x..xxx..x",
    "xx..x..xx",
    ".x.....x.",
    "..xxxxx..",
]
PHOENIX = [
    "..........xx",
    "x.......xxo.",
    "xx....xxxx..",
    ".xxx.xxxx...",
    "..xxxxxx....",
    "...xxxx.x.x.",
    "..x.x..x.x.x",
]
SHIP = [
    "....x.....",
    "...xxx....",
    "..xxxxx...",
    "....x.....",
    "xxxxxxxxxx",
    ".xxxxxxxx.",
]
ZBIRD = [
    "...xx.",
    "..xxxx",
    ".xxx..",
    "xxxx..",
    ".xxx..",
    "..xx..",
    "..xx..",
    ".xxxx.",
    ".xxxx.",
    "xxxxxx",
]
STOOL = ["xxxxxx", ".x..x.", "..xx..", "..xx..", ".x..x.", "xxxxxx"]
PYRAMID = [
    "....xxxx....",
    "....x..x....",
    "...xxxxxx...",
    "..xxx..xxx..",
    ".xxxx..xxxx.",
    "xxxxx..xxxxx",
]
CELTIC = [
    "....x....",
    "....x....",
    "..xxxxx..",
    ".x..x..x.",
    "xxxxxxxxx",
    ".x..x..x.",
    "..xxxxx..",
    "....x....",
    "....x....",
    "....x....",
]
TRINACRIA = [
    "....x....",
    "....x.x..",
    "....x....",
    "...ooo...",
    "..ooooo..",
    "...ooo...",
    "..x...x..",
    ".x.....x.",
    "xx.....xx",
]
SOYOMBO = ["..x..", ".x.x.", "..x..", "xxxxx", "..x..", ".xxx.", "xx.xx", ".xxx.", "xxxxx", "x...x"]
SHIELD_KE = [
    "..xx..",
    ".xxxx.",
    "xxxxxx",
    "oxxxxo",
    "oxwwxo",
    "oxwwxo",
    "oxxxxo",
    "xxxxxx",
    ".xxxx.",
    "..xx..",
]
CHECKER = ["xoxo", "oxox", "xoxo", "oxox", ".xo."]
DRAGON_S = [
    "xx......",
    "xox..x..",
    ".xxxxxx.",
    "...xx.xx",
    "...x...x",
]
CROWN = [
    "x....xx....x",
    "xx..xxxx..xx",
    "xxx.xxxx.xxx",
    "xxxxxxxxxxxx",
    "xoxxoxxoxxox",
    "xxxxxxxxxxxx",
]


def union_canton(f, x1=8, y1=5):
    """A small Union Flag in the canton, (0, 0) to (x1, y1)."""
    f.rect(0, 0, x1, y1, "navy")
    for y in range(y1 + 1):
        for x in range(x1 + 1):
            u, v = x / x1, y / y1
            d = min(abs(u - v), abs(u - (1 - v))) * y1
            if d < 0.95:
                f.set(x, y, "white")
            if d < 0.35:
                f.set(x, y, "red")
    cx, cy = x1 // 2, y1 // 2
    f.rect(cx - 1, 0, cx + 1, y1, "white").rect(0, cy - 1, x1, cy + 1, "white")
    f.rect(cx, 0, cx, y1, "red").rect(0, cy, x1, cy, "red")
    return f


def korea():
    f = F().fill("white")
    for y in range(H):
        for x in range(W):
            if (x + 0.5 - 9) ** 2 + (y + 0.5 - 6) ** 2 <= 3.2 ** 2:
                f.set(x, y, "red" if y + 0.5 < 6 else "blue")
    for x0, y0, rows in ((1, 1, ["xxx", "...", "xxx", "...", "xxx"]), (14, 1, ["xxx", "...", "x.x", "...", "xxx"]),
                         (1, 6, ["x.x", "...", "xxx", "...", "x.x"]), (14, 6, ["x.x", "...", "x.x", "...", "x.x"])):
        f.shape(x0, y0, rows, {"x": "black"})
    return f


def south_africa():
    f = F()
    for y in range(H):
        for x in range(W):
            f.set(x, y, "red" if y < 6 else "blue")
            if x <= 8:
                d = min(abs(y + 0.5 - (0.5 + x * 5 / 8)), abs(y + 0.5 - (11.5 - x * 5 / 8)))
            else:
                d = abs(y + 0.5 - 6)
            if d <= 1.9:
                f.set(x, y, "white")
            if d <= 1.0:
                f.set(x, y, "darkgreen")
            reach = 5.5 * (1 - abs(y + 0.5 - 6) / 4.5)
            if x + 0.5 <= reach:
                f.set(x, y, "gold")
            if x + 0.5 <= reach - 1.3:
                f.set(x, y, "black")
    return f


def jamaica():
    f = F()
    for y in range(H):
        for x in range(W):
            u, v = x / (W - 1), y / (H - 1)
            if abs(u - v) * (H - 1) < 1.3 or abs(u - (1 - v)) * (H - 1) < 1.3:
                f.set(x, y, "gold")
            else:
                dx, dy = (x + 0.5 - 9) / 9, (y + 0.5 - 6) / 6
                f.set(x, y, "darkgreen" if abs(dy) > abs(dx) else "black")
    return f


def sun_emperor():
    f = F().fill("crimson")
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - 9, y + 0.5 - 6
            a = math.degrees(math.atan2(dy, dx)) % 30
            if math.hypot(dx, dy) > 3 and (a < 7 or a > 23):
                f.set(x, y, "gold")
    return f.disc(9, 6, 3.2, "gold").disc(9, 6, 1.8, "orange")


def medici():
    f = F().fill("gold")
    for cx, cy, c in ((8.5, 1.5, "blue"), (5.5, 4.5, "red"), (11.5, 4.5, "red"), (4.5, 7.5, "red"),
                      (12.5, 7.5, "red"), (8.5, 10.5, "red")):
        f.disc(cx, cy, 1.45, c)
    return f


def border(f, c):
    return f.rect(0, 0, W - 1, 0, c).rect(0, H - 1, W - 1, H - 1, c).rect(0, 0, 0, H - 1, c).rect(W - 1, 0, W - 1, H - 1, c)


# nations of today (common: plain stripes; rare: an emblem)
add("nigeria", "Nigeria", "common", F().vstripes("green", "white", "green"))
add("ghana", "Ghana", "common", F().hstripes("red", "yellow", "green").star(9, 6, "black", big=True))
add("indonesia", "Indonesia", "common", F().hstripes("red", "white"))
add("bangladesh", "Bangladesh", "common", F().fill("darkgreen").disc(8, 6, 3.6, "red"))
add("vietnam", "Vietnam", "common", F().fill("red").shape(6, 2, STAR5, {"x": "yellow"}))
add("china", "China", "rare", (lambda f: [f.star(x, y, "yellow") for x, y in ((10, 1), (13, 3), (13, 6), (10, 8))] and f)(
    F().fill("red").shape(1, 1, STAR5, {"x": "yellow"})))
add("south_korea", "South Korea", "rare", korea())
add("pakistan", "Pakistan", "rare", F().fill("darkgreen").rect(0, 0, 4, H - 1, "white").crescent(11, 6, 3.4, "white", off=1.3).star(13, 4, "white"))
add("morocco", "Morocco", "rare", F().fill("red").shape(6, 2, ["...x...", "..x.x..", "xxxxxxx", ".x...x.", "..x.x..", ".x.x.x.", "x.....x"], {"x": "darkgreen"}))
add("algeria", "Algeria", "rare", F().vstripes("green", "white").crescent(9.5, 6, 3.5, "red", off=1.3).star(11, 6, "red"))
add("kenya", "Kenya", "rare", F().rect(0, 0, W - 1, 3, "black").rect(0, 4, W - 1, 4, "white").rect(0, 5, W - 1, 6, "red")
    .rect(0, 7, W - 1, 7, "white").rect(0, 8, W - 1, H - 1, "darkgreen").shape(6, 1, SHIELD_KE, {"x": "red", "o": "black", "w": "white"}))
add("egypt", "Egypt", "rare", F().hstripes("red", "white", "black").shape(6, 3, EAGLE, {"x": "gold"}))
add("south_africa", "South Africa", "rare", south_africa())
add("australia", "Australia", "rare", (lambda f: [f.star(x, y, "white") for x, y in ((13, 2), (16, 5), (11, 6), (13, 9))] and f.star(4, 9, "white", big=True))(union_canton(F().fill("navy"))))
add("new_zealand", "New Zealand", "rare", (lambda f: [f.star(x, y, "red") for x, y in ((13, 2), (16, 5), (11, 5), (13, 9))] and f)(union_canton(F().fill("navy"))))
add("jamaica", "Jamaica", "rare", jamaica())
add("cuba", "Cuba", "rare", F().hstripes("blue", "white", "blue", "white", "blue").tri(8, "red").star(3, 6, "white", big=True))
add("uruguay", "Uruguay", "rare", F().hstripes("white", "blue", "white", "blue", "white", "blue", "white", "blue", "white")
    .rect(0, 0, 6, 5, "white").shape(1, 1, ["x.x.x", ".xxx.", "xxxxx", ".xxx.", "x.x.x"], {"x": "gold"}))
add("czechia", "Czechia", "common", F().hstripes("white", "red").tri(9, "blue"))
add("croatia", "Croatia", "rare", F().hstripes("red", "white", "blue").shape(7, 3, CHECKER, {"x": "red", "o": "white"}))
add("latvia", "Latvia", "common", F().fill("maroon").rect(0, 5, W - 1, 6, "white"))
add("armenia", "Armenia", "common", F().hstripes("red", "blue", "orange"))
add("georgia", "Georgia", "rare", (lambda f: [f.shape(x, y, [".x.", "xxx", ".x."], {"x": "red"}) for x, y in ((3, 1), (13, 1), (3, 8), (13, 8))] and f)(
    F().fill("white").cross(8, 5, 2, "red")))
add("russia", "Russia", "common", F().hstripes("white", "blue", "red"))
add("kazakhstan", "Kazakhstan", "rare", (lambda f: [f.set(1, y, "gold") for y in range(0, H, 2)] and [f.set(2, y, "gold") for y in range(1, H, 2)] and f)(
    F().fill("kazblue").disc(10, 4.5, 2.3, "gold").shape(6, 7, ["x.......x", "xxx...xxx", ".xxxxxxx."], {"x": "gold"})))
add("mongolia", "Mongolia", "rare", F().vstripes("red", "blue", "red").shape(1, 1, SOYOMBO, {"x": "gold"}))

# kingdoms, clans and banners of history
add("hawaii", "Kingdom of Hawaii", "epic", union_canton(F().hstripes("white", "red", "blue", "white", "red", "blue", "white", "red")))
add("texas", "Republic of Texas", "rare", F().fill("white").rect(0, 6, W - 1, H - 1, "red").rect(0, 0, 5, H - 1, "blue").star(3, 6, "white", big=True))
add("plantagenet", "Three Lions of England", "epic", (lambda f: [f.shape(5, y, LION_S, {"x": "gold"}) for y in (1, 5, 9)] and f)(F().fill("red")))
add("leon", "Kingdom of León", "rare", F().fill("white").shape(5, 3, LION, {"x": "purple"}))
add("bohemia", "Kingdom of Bohemia", "rare", F().fill("red").shape(5, 3, LION, {"x": "white"}))
add("lion_rampant", "Lion Rampant", "epic", border(F().fill("gold"), "red").rect(2, 2, W - 3, 2, "red").shape(5, 2, RAMPANT, {"x": "red"}))
add("sicily", "Kingdom of Sicily", "epic", (lambda f: f.shape(5, 1, TRINACRIA, {"x": "flesh", "o": "gold"}))(
    (lambda f: [f.set(x, y, "red" if x / (W - 1) + y / (H - 1) < 1 else "yellow") for y in range(H) for x in range(W)] and f)(F())))
add("florence", "Republic of Florence", "rare", F().fill("white").shape(5, 2, GIGLIO, {"x": "red"}))
add("medici", "House of Medici", "epic", medici())
add("navarre", "Kingdom of Navarre", "rare", border(F().fill("red").saltire(0.6, "gold").rect(8, 0, 8, H - 1, "gold").rect(0, 5, W - 1, 5, "gold"), "gold").disc(8.5, 5.5, 1.2, "green"))
add("takeda", "Takeda Clan", "epic", (lambda f: [f.shape(x, y, D5, {"x": "black"}) for x, y in ((7, 0), (4, 3), (10, 3), (7, 6))] and f)(F().fill("white")))
add("sanada", "Sanada Clan", "epic", (lambda f: [f.shape(x, y, COIN, {"x": "black"}) for x in (2, 7, 12) for y in (1, 6)] and f)(F().fill("red")))
add("oda", "Oda Clan", "rare", F().fill("yellow").shape(4, 2, MOKKO, {"x": "black"}))
add("tang", "Tang Phoenix", "epic", F().fill("yellow").shape(3, 2, PHOENIX, {"x": "red", "o": "gold"}))
add("babylon", "Babylon", "epic", (lambda f: [f.set(x, y, "gold" if x % 3 == 1 else "white") for x in range(W) for y in (0, H - 1) if x % 3 != 2] and f)(
    F().fill("lapis").shape(5, 3, LION, {"x": "gold"})))
add("tyre", "Tyre of Phoenicia", "epic", F().fill("purple").shape(4, 2, SHIP, {"x": "gold"}).rect(0, 9, W - 1, 9, "lightblue").rect(0, 10, W - 1, H - 1, "blue"))
add("zimbabwe_bird", "Great Zimbabwe", "rare", F().fill("darkgreen").shape(6, 1, ZBIRD, {"x": "gold"}))
add("ashanti", "Ashanti Empire", "rare", F().hstripes("yellow", "darkgreen", "black").shape(6, 3, STOOL, {"x": "gold"}))
add("maya", "Maya", "rare", F().fill("darkgreen").shape(3, 4, PYRAMID, {"x": "gold"}))
add("celtic", "Celtic Cross", "rare", F().fill("darkgreen").shape(4, 1, CELTIC, {"x": "gold"}))
add("legion", "Legion Vexillum", "epic", (lambda f: [f.set(x, H - 1, "gold") for x in range(0, W, 2)] and f)(
    F().fill("crimson").rect(0, 0, W - 1, 0, "gold").shape(6, 2, EAGLE, {"x": "gold"}).rect(8, 8, 10, 9, "gold")))
add("viking_sail", "Viking Sail", "rare", F().vstripes("red", "white", "red", "white", "red", "white"))

# legendary banners, the Stars' top prize
add("sun_emperor", "Sun Emperor", "legendary", sun_emperor())
add("twin_dragons", "Twin Dragons", "legendary", border(F().fill("navy"), "gold").shape(1, 1, mirror(DRAGON), {"x": "gold", "o": "red"})
    .shape(4, 6, DRAGON, {"x": "gold", "o": "red"}))
add("golden_eagle", "Golden Double Eagle", "legendary", border(F().fill("purple"), "gold").shape(5, 2, DOUBLE_EAGLE, {"x": "gold"}))
add("celestial", "Celestial Night", "legendary", (lambda f: [f.set(x, y, "white") for x, y in ((12, 2), (15, 4), (11, 8), (14, 9), (16, 1), (9, 1), (16, 10))] and f.star(13, 6, "gold", big=True))(
    F().fill("navy").crescent(6, 6, 3.8, "gold", off=1.5)))
add("conqueror", "Conqueror's Crown", "legendary", F().fill("black").shape(3, 3, CROWN, {"x": "gold", "o": "red"}).rect(3, 10, 14, 10, "gold"))

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
