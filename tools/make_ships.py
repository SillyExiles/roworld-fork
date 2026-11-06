"""Empires Front ship sprites: side-view pixel art, 32 x 32, grey-scale (tinted by the owner's colour in
game, so 255 = the full owner colour and darker greys are its shades). Bow faces right; the game mirrors
the sprite for ships heading left.
Writes Luau data (run-length rows of palette letters, one per grey) for client/Map/ShipArt and, with --preview PATH, a preview sheet.

Styles (see ShipArt.STYLE_OF_ERA; 2026-11-06: every era its own):
  ancient    Rome       trireme / corbita / small galley
  greek      Greece     trireme rowed into battle / holkas merchant / penteconter
  dhow       Persia     lateen-rigged dhows
  niger      Mali       war dhow / pinasse under mat canopies / river canoe
  galley     Ottoman    kadirga war galley / lateen merchant / oared transport
  junk       China      battened-sail junks
  yuan       Mongols    war junk with a horse-tail standard / barge with a ger / horse transport
  japan      Japan      atakebune / bezaisen / sekibune
  canoe      Aztec      war canoe / cargo acalli / dugout
  raft       Inca       balsa war raft / balsa sailing raft / totora reed boat
  steam      Russia     dreadnought / cargo steamer / troopship
  victorian  Britain    ironclad / steam clipper / liner
  sail       Nations    ship of the line / fluyt / brig
"""
import sys
from PIL import Image

N = 32
# tones
O = 48          # outline
HD = 100        # hull shadow
H = 140         # hull
HL = 172        # hull light (upper strake)
TRIM = 235      # gunwale / gilding
DECK = 120
MAST = 85
ROPE = 120
SAIL = 255
SS = 222        # sail shade
SD = 186        # sail deep shade / panel line
WIN = 60        # windows, gun ports
EMB = 150       # emblem on sails


class Spr:
    def __init__(self):
        self.px = {}
        self.post = {}   # thin parts (oars, paddles, rigging) drawn after the outline

    def late(self, x, y, v):
        if 0 <= x < N and 0 <= y < N:
            self.post[(x, y)] = v

    def put(self, x, y, v):
        if 0 <= x < N and 0 <= y < N:
            self.px[(x, y)] = v

    def get(self, x, y):
        return self.px.get((x, y))

    def rect(self, x0, y0, x1, y1, v):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, v)

    def line(self, x0, y0, x1, y1, v):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), v)

    def outline(self):
        """Dark 1-px outline around every drawn pixel (where empty)."""
        add = {}
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in self.px and 0 <= q[0] < N and 0 <= q[1] < N:
                    add[q] = O
        self.px.update(add)
        for q, v in self.post.items():
            if q not in self.px or self.px[q] == O:
                self.px[q] = v

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for (x, y), v in self.px.items():
            im.putpixel((x, y), (v, v, v, 255))
        return im


# ---------------------------------------------------------------- parts
def hull(s, x0, x1, top, stern, bow, strakes=True, line=None):
    """Hull from x0 (stern) to x1 (bow), gunwale at row `top`. `stern`/`bow` are per-row insets (one
    entry per row, top to keel). Shaded: gilded gunwale, light upper strake, plank lines, dark bilge."""
    depth = len(stern)
    for i in range(depth):
        y = top + i
        a, b = x0 + stern[i], x1 - bow[i]
        for x in range(a, b + 1):
            if i == 0:
                v = TRIM
            elif i == 1:
                v = HL
            elif i >= depth - 1:
                v = HD
            else:
                v = H
            s.put(x, y, v)
        if strakes and 2 <= i < depth - 1 and i % 2 == 0:
            for x in range(a + 1, b):
                s.put(x, y, HD if (x + i) % 7 else H)
    if line is not None:   # a painted wale along the hull
        y = top + line
        for x in range(x0 + stern[line] + 1, x1 - bow[line]):
            s.put(x, y, WIN)


def castle(s, x0, x1, y0, y1, windows=True, rail=True):
    s.rect(x0, y0, x1, y1, H)
    s.rect(x0, y0, x1, y0, TRIM)
    if windows and y1 - y0 >= 2:
        for x in range(x0 + 1, x1, 2):
            s.put(x, y0 + 2, WIN)
    if rail:
        for x in range(x0, x1 + 1, 2):
            s.put(x, y0 - 1, HL)


def mast(s, x, y0, y1, v=MAST):
    for y in range(y0, y1 + 1):
        s.put(x, y, v)


def sail(s, x0, y0, x1, y1, belly=1, shade_right=True, bands=(), emblem=None):
    """Square sail between the yards at y0 and y1, bulging `belly` px at mid-height, shaded on the lee
    side, with optional reef bands (rows) and an emblem ('cross', 'stripe', 'disc')."""
    h = y1 - y0
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(h, 1)
        b = round(belly * (1 - (2 * t - 1) ** 2))
        a, c = x0 - (b // 2), x1 + b - (b // 2)
        for x in range(a, c + 1):
            v = SAIL
            if shade_right and x >= c - 1:
                v = SS
            if not shade_right and x <= a + 1:
                v = SS
            if y == y1:
                v = SS
            if y in bands:
                v = SD
            s.put(x, y, v)
    # yards
    s.rect(x0 - 1, y0 - 1, x1 + 1, y0 - 1, MAST)
    xm, ym = (x0 + x1) // 2, (y0 + y1) // 2
    if emblem == "cross":
        for k in range(-2, 3):
            s.put(xm, ym + k, EMB)
            s.put(xm + k, ym, EMB)
    elif emblem == "stripe":
        for y in range(y0, y1 + 1):
            s.put(xm, y, SD)
            s.put(xm + 1, y, SD)
    elif emblem == "disc":
        for dx, dy in ((0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
            s.put(xm + dx, ym + dy, EMB)


def lateen(s, tack, peak, clew, seams=4):
    """Triangular lateen sail: the yard runs from the `tack` (low, forward) up to the `peak` (high, aft);
    the sail hangs from it down to the `clew` (low, aft). Seams parallel to the leech, shaded foot."""
    (ax, ay), (bx, by), (cx, cy) = tack, peak, clew

    def cross(ox, oy, px, py, qx, qy):
        return (px - ox) * (qy - oy) - (py - oy) * (qx - ox)

    area = cross(ax, ay, bx, by, cx, cy)
    for y in range(min(ay, by, cy), max(ay, by, cy) + 1):
        for x in range(min(ax, bx, cx), max(ax, bx, cx) + 1):
            w1 = cross(ax, ay, bx, by, x, y) / area
            w2 = cross(bx, by, cx, cy, x, y) / area
            w3 = cross(cx, cy, ax, ay, x, y) / area
            if w1 >= -0.02 and w2 >= -0.02 and w3 >= -0.02:
                v = SAIL
                if w2 * abs(area) < 1.6 * ((bx - cx) ** 2 + (by - cy) ** 2) ** 0.5:
                    v = SD           # the leech (aft edge)
                elif y >= cy and w1 < 0.25:
                    v = SS
                elif seams and (x - cx) % seams == seams - 1:
                    v = SS
                s.put(x, y, v)
    # the yard, from just past the peak to past the tack
    n = max(abs(ax - bx), 1)
    k = (ay - by) / n
    s.line(bx - 1, round(by - k), ax + 2, round(ay + 2 * k), MAST)


def jib(s, x_mast, y_top, x_tip, y_bot):
    """Triangular headsail from the masthead to the bowsprit tip."""
    for y in range(y_top, y_bot + 1):
        t = (y - y_top) / max(y_bot - y_top, 1)
        xr = round(x_mast + (x_tip - x_mast) * t)
        for x in range(x_mast + 1, xr + 1):
            s.put(x, y, SAIL if x < xr else SS)


def junk_sail(s, xm, y0, y1, w_top, w_bot, step=3, fore=1):
    """Battened junk sail hung on the mast at xm: mostly aft of it, the leech bellying out in a fan,
    dark battens every `step` rows that stick out past the leech."""
    import math
    h = max(y1 - y0, 1)
    for y in range(y0, y1 + 1):
        t = (y - y0) / h
        w = round(w_top + (w_bot - w_top) * math.sin(t * math.pi / 2))
        a, c = xm - w, xm + fore
        batten = (y - y0) % step == 0
        for x in range(a - (1 if batten and y > y0 else 0), c + 1):
            v = SD if batten else SAIL
            if not batten and x <= a:
                v = SS
            s.put(x, y, v)
    mast(s, xm, y0 - 1, y1)


def oars(s, xs, y, step=2, length=4, slope=1):
    for x in xs[::1]:
        if (x - xs[0]) % step:
            continue
        for k in range(length):
            s.late(x - k * slope // 2, y + k, O if k < length - 1 else MAST)


def pennant(s, x, y, length=3, v=TRIM):
    for k in range(length):
        s.put(x + 1 + k, y + (1 if k == length - 1 else 0), v)
    s.put(x, y, MAST)


def flagpole_flag(s, x, y):
    s.rect(x + 1, y, x + 3, y + 1, TRIM)
    s.put(x, y, MAST)
    s.put(x, y + 1, MAST)


def eye(s, x, y):
    s.put(x, y, SAIL)
    s.put(x + 1, y, WIN)


# ---------------------------------------------------------------- antiquity (Rome, Greece)
def trireme():
    s = Spr()
    hull(s, 2, 26, 18, stern=[3, 2, 2, 3, 5], bow=[2, 1, 1, 2, 3], line=2)
    # curled stern post (aphlaston)
    s.rect(3, 15, 4, 17, H)
    s.put(4, 14, HL); s.put(3, 13, HL); s.put(2, 13, TRIM); s.put(2, 14, TRIM)
    # bronze ram + eye
    s.rect(26, 21, 29, 21, HL); s.put(30, 21, TRIM); s.put(29, 20, H)
    eye(s, 23, 19)
    # bow post
    s.put(26, 17, HL); s.put(27, 16, TRIM)
    mast(s, 14, 3, 17)
    sail(s, 9, 4, 19, 12, belly=2, bands=(), emblem="stripe")
    # deck shields
    for x in range(6, 24, 3):
        s.put(x, 17, TRIM)
    oars(s, range(5, 25), 23, step=2, length=5)
    pennant(s, 14, 2)
    s.outline()
    return s


def corbita():
    s = Spr()
    hull(s, 3, 26, 17, stern=[1, 1, 1, 2, 3, 5, 7], bow=[3, 2, 1, 1, 2, 3, 5], line=3)
    # swan-neck stern
    s.rect(3, 14, 5, 16, H)
    s.put(4, 13, HL); s.put(5, 12, HL); s.put(6, 11, TRIM); s.put(7, 11, TRIM)
    # deck house
    castle(s, 6, 10, 14, 16, windows=False)
    mast(s, 16, 2, 16)
    sail(s, 10, 3, 22, 12, belly=3, bands=(7,))
    # artemon (bow foresail) on a raked spar
    s.line(24, 16, 28, 9, MAST)
    sail(s, 25, 10, 28, 13, belly=0)
    s.outline()
    return s


def liburna():
    s = Spr()
    hull(s, 5, 25, 19, stern=[2, 1, 2, 4], bow=[1, 1, 2, 3], line=2)
    s.rect(5, 16, 6, 18, H); s.put(5, 15, TRIM)
    s.rect(25, 21, 27, 21, HL)
    eye(s, 22, 20)
    mast(s, 15, 7, 18)
    sail(s, 11, 8, 19, 14, belly=1)
    for x in range(8, 24, 3):  # legionaries' shields
        s.rect(x, 17, x + 1, 18, TRIM)
    oars(s, range(8, 24), 23, step=3, length=4)
    s.outline()
    return s


# ---------------------------------------------------------------- dhows (Persia, Mali)
def baghlah():
    s = Spr()
    hull(s, 2, 27, 18, stern=[0, 0, 1, 2, 4, 6], bow=[0, 2, 4, 5, 6, 8], line=2)
    castle(s, 2, 8, 15, 17)          # carved transom stern
    s.rect(27, 17, 30, 17, MAST)     # long raked prow
    lateen(s, (23, 16), (4, 1), (5, 16))
    mast(s, 13, 3, 17)
    lateen(s, (30, 16), (19, 6), (20, 16))
    mast(s, 22, 8, 17)
    for x in (11, 15, 19, 23):
        s.put(x, 20, WIN)
    s.outline()
    return s


def boom():
    s = Spr()
    hull(s, 3, 27, 18, stern=[2, 1, 1, 2, 3, 5], bow=[0, 1, 2, 4, 6, 8], line=None)
    s.line(2, 17, 4, 19, HL)          # double-ended pointed stern
    lateen(s, (26, 16), (5, 1), (6, 16))
    mast(s, 14, 2, 17)
    # cargo bales
    for x in (7, 11, 18):
        s.rect(x, 16, x + 2, 17, DECK)
        s.put(x + 1, 16, HL)
    s.outline()
    return s


def sambuk():
    s = Spr()
    hull(s, 5, 26, 19, stern=[0, 1, 2, 4], bow=[0, 2, 3, 5])
    castle(s, 5, 9, 17, 18, windows=False)
    s.rect(26, 18, 28, 18, MAST)
    lateen(s, (26, 17), (8, 3), (9, 17))
    mast(s, 15, 6, 18)
    for x in (12, 18, 21):
        s.rect(x, 17, x, 18, TRIM)
        s.put(x, 16, HL)
    s.outline()
    return s


# ---------------------------------------------------------------- Ottoman galleys
def kadirga():
    s = Spr()
    hull(s, 2, 27, 19, stern=[1, 1, 2, 3, 5], bow=[0, 1, 2, 3, 4], line=2)
    castle(s, 2, 7, 16, 18)                       # stern platform
    s.put(4, 15, HL); s.put(4, 14, TRIM)          # stern lantern
    s.rect(27, 18, 31, 18, MAST)                  # spur
    lateen(s, (22, 17), (3, 2), (5, 17))
    mast(s, 12, 4, 18)
    lateen(s, (30, 17), (18, 7), (19, 17))
    mast(s, 21, 9, 18)
    s.rect(24, 17, 26, 18, HL)                    # bow gun platform
    s.put(27, 17, WIN)
    oars(s, range(6, 26), 24, step=2, length=5)
    s.outline()
    return s


def mavna():
    s = Spr()
    hull(s, 2, 27, 17, stern=[0, 0, 1, 2, 3, 5, 7], bow=[1, 1, 2, 3, 4, 6, 8], line=3)
    castle(s, 2, 8, 13, 16)
    s.rect(27, 16, 30, 16, MAST)
    lateen(s, (24, 15), (5, 0), (7, 15))
    mast(s, 15, 2, 16)
    lateen(s, (31, 15), (21, 5), (22, 15))
    mast(s, 22, 8, 16)
    for x in range(10, 26, 4):
        s.put(x, 20, WIN)
    s.outline()
    return s


def firkate():
    s = Spr()
    hull(s, 5, 26, 19, stern=[1, 1, 2, 3], bow=[0, 1, 2, 3])
    castle(s, 5, 8, 17, 18, windows=False)
    s.rect(26, 18, 29, 18, MAST)
    lateen(s, (26, 17), (8, 3), (9, 17))
    mast(s, 16, 7, 18)
    for x in range(10, 24, 3):     # janissary caps
        s.put(x, 18, TRIM); s.put(x, 17, SAIL)
    oars(s, range(8, 25), 23, step=3, length=4)
    s.outline()
    return s


# ---------------------------------------------------------------- junks (China, Mongols)
def fuchuan():
    s = Spr()
    hull(s, 1, 28, 19, stern=[0, 0, 0, 1, 2, 4], bow=[1, 1, 2, 3, 5, 7], line=2)
    castle(s, 1, 8, 15, 18)                      # tall stern castle
    s.rect(1, 14, 8, 14, TRIM)
    s.put(1, 13, HL); s.put(8, 13, HL)
    castle(s, 23, 27, 16, 18, windows=False)     # forecastle
    junk_sail(s, 17, 2, 16, 3, 7, step=3)
    mast(s, 17, 17, 18)
    junk_sail(s, 24, 7, 14, 2, 4, step=2)
    junk_sail(s, 6, 6, 11, 2, 3, step=2)
    eye(s, 25, 20)
    for x in range(9, 24, 3):
        s.put(x, 22, WIN)
    pennant(s, 17, 0, 3)
    s.outline()
    return s


def shachuan():
    s = Spr()
    hull(s, 2, 28, 18, stern=[0, 0, 1, 2, 3, 5], bow=[0, 0, 1, 2, 4, 6], line=2)
    castle(s, 2, 8, 15, 17, windows=False)
    s.rect(9, 15, 12, 17, DECK); s.rect(9, 15, 12, 15, HL)   # deck house
    junk_sail(s, 18, 3, 15, 3, 7, step=3)
    mast(s, 18, 16, 17)
    junk_sail(s, 25, 8, 15, 2, 4, step=2)
    mast(s, 25, 16, 17)
    s.outline()
    return s


def troop_junk():
    s = Spr()
    hull(s, 4, 26, 19, stern=[0, 0, 1, 3, 5], bow=[1, 1, 2, 4, 6])
    castle(s, 4, 9, 16, 18, windows=False)
    junk_sail(s, 18, 5, 16, 3, 6, step=3)
    mast(s, 18, 17, 18)
    for x in (11, 21, 23):
        s.rect(x, 17, x, 18, TRIM); s.put(x, 16, HL)
    eye(s, 23, 20)
    s.outline()
    return s


# ---------------------------------------------------------------- Japan
def atakebune():
    s = Spr()
    hull(s, 1, 28, 20, stern=[0, 0, 1, 2, 4], bow=[0, 0, 1, 3, 5], line=None)
    # boxy armoured superstructure with loopholes
    s.rect(3, 13, 25, 19, H)
    s.rect(3, 13, 25, 13, TRIM)
    for x in range(5, 25, 3):
        s.put(x, 15, WIN); s.put(x, 17, WIN)
    # tower (yagura) with a curved roof
    s.rect(8, 8, 16, 12, HL)
    s.rect(7, 7, 17, 7, TRIM)
    s.put(6, 6, TRIM); s.put(18, 6, TRIM)
    for x in (10, 12, 14):
        s.put(x, 10, WIN)
    mast(s, 21, 2, 12)
    sail(s, 19, 3, 24, 11, belly=0, emblem=None, bands=(5, 8))
    oars(s, range(4, 26), 25, step=2, length=4)
    flagpole_flag(s, 12, 3)
    mast(s, 12, 5, 6)
    s.outline()
    return s


def bezaisen():
    s = Spr()
    hull(s, 2, 27, 19, stern=[0, 0, 1, 2, 3, 5], bow=[0, 1, 2, 4, 6, 8], line=2)
    castle(s, 2, 7, 15, 18, windows=False)          # high stern / rudder house
    s.line(25, 18, 30, 14, HL)                       # raked stem
    s.put(30, 13, TRIM)
    mast(s, 15, 1, 18)
    # one great sail of vertical cloth strips
    for x in range(9, 22):
        for y in range(2, 15):
            s.put(x, y, SD if (x - 9) % 3 == 2 else (SS if x == 21 else SAIL))
    s.rect(8, 1, 22, 1, MAST)
    s.outline()
    return s


def sekibune():
    s = Spr()
    hull(s, 4, 27, 19, stern=[0, 0, 1, 3], bow=[0, 1, 2, 4])
    s.rect(6, 15, 22, 18, H)
    s.rect(6, 15, 22, 15, TRIM)
    for x in range(8, 22, 3):
        s.put(x, 17, WIN)
    mast(s, 17, 6, 14)
    for x in range(13, 21):
        for y in range(7, 13):
            s.put(x, y, SD if (x - 13) % 3 == 2 else SAIL)
    oars(s, range(7, 24), 23, step=3, length=4)
    pennant(s, 17, 5, 2)
    s.outline()
    return s


# ---------------------------------------------------------------- Americas (Inca, Aztec)
def war_canoe():
    s = Spr()
    hull(s, 2, 29, 19, stern=[0, 0, 1, 3, 6], bow=[0, 0, 1, 3, 6], strakes=False, line=2)
    s.rect(1, 16, 2, 18, HL); s.put(1, 15, TRIM); s.put(0, 14, TRIM)     # carved serpent ends
    s.rect(29, 16, 30, 18, HL); s.put(30, 15, TRIM); s.put(31, 14, TRIM)
    eye(s, 26, 17)
    for x in range(6, 26, 4):                        # warriors: feathered heads, shields
        s.rect(x, 16, x + 1, 18, HL)
        s.put(x, 15, TRIM); s.put(x + 1, 14, SAIL)
    s.rect(13, 6, 18, 12, SAIL)                      # feathered war banner
    s.rect(13, 12, 18, 12, SS)
    for x in (14, 16):
        s.rect(x, 8, x + 1, 10, EMB)
    mast(s, 15, 4, 15)
    s.outline()
    for x in range(7, 26, 4):                        # paddles in the water
        s.line(x + 3, 20, x, 26, MAST)
    return s


def balsa_raft():
    s = Spr()
    # log raft, blunt ends
    for y, (a, b) in enumerate(((3, 27), (2, 28), (3, 27))):
        for x in range(a, b + 1):
            s.put(x, 20 + y, HL if y == 0 else (H if x % 3 else HD))
    s.rect(6, 17, 11, 19, DECK)                      # hut
    s.rect(5, 16, 12, 16, TRIM)
    s.put(8, 18, WIN)
    # bipod mast + square cotton sail
    s.line(16, 19, 19, 3, MAST)
    s.line(22, 19, 19, 3, MAST)
    sail(s, 14, 5, 24, 14, belly=2, emblem="disc")
    # centreboards (guaras)
    for x in (9, 17, 24):
        s.rect(x, 23, x, 25, MAST)
    s.outline()
    return s


def dugout():
    s = Spr()
    hull(s, 4, 27, 19, stern=[0, 0, 2, 4], bow=[0, 0, 2, 4], strakes=False, line=1)
    s.put(3, 18, TRIM); s.put(28, 18, TRIM); s.put(2, 17, TRIM); s.put(29, 17, TRIM)
    for x in range(7, 25, 3):                        # warriors with round shields
        s.rect(x, 16, x, 18, HL)
        s.put(x, 15, TRIM)
        s.rect(x + 1, 17, x + 1, 18, SAIL)
    s.outline()
    for x in range(7, 25, 3):
        s.line(x - 1, 19, x - 3, 24, MAST)
    return s


# ---------------------------------------------------------------- Age of Sail (Russia, Britain, Nations)
def square_rig(s, xm, rows, hw, emblem_row=None):
    """A mast at xm carrying square sails, one per (y0, y1) in `rows` (top to bottom), each half-width
    `hw` (+1 on the lower ones); the dark outline between them reads as the yards."""
    for k, (y0, y1) in enumerate(rows):
        w = hw + (1 if k == len(rows) - 1 else 0)
        for y in range(y0, y1 + 1):
            mid = 0 < y - y0 < y1 - y0
            for x in range(xm - w - (1 if mid and k == len(rows) - 1 else 0), xm + w + 1):
                v = SAIL
                if x >= xm + w - 0 or y == y1:
                    v = SS
                s.put(x, y, v)
        if emblem_row is not None and k == emblem_row:
            ym = (y0 + y1) // 2
            for d in (-1, 0, 1):
                s.put(xm + d, ym, EMB)
                s.put(xm, ym + d, EMB)
    mast(s, xm, rows[0][0] - 2, rows[-1][1])
    s.put(xm, rows[0][0] - 1, MAST)


def ship_of_line():
    s = Spr()
    hull(s, 1, 28, 19, stern=[0, 0, 0, 0, 1, 2, 4], bow=[2, 1, 1, 1, 2, 4, 6], strakes=False)
    for row in (21, 23):                          # two gun decks, a light band above each
        for x in range(3, 26):
            if s.get(x, row - 1) is not None:
                s.put(x, row - 1, HL)
        for x in range(4, 25, 2):
            s.put(x, row, WIN)
    castle(s, 1, 6, 16, 18)                       # quarterdeck / stern gallery
    s.put(1, 15, TRIM); s.put(6, 15, TRIM)
    s.rect(27, 17, 31, 17, MAST)                  # bowsprit
    square_rig(s, 7, [(8, 10), (12, 16)], 2)
    square_rig(s, 15, [(2, 4), (6, 9), (11, 16)], 3, emblem_row=2)
    square_rig(s, 23, [(5, 7), (9, 11), (13, 16)], 2)
    jib(s, 25, 5, 31, 16)
    pennant(s, 15, 0, 4)
    s.outline()
    return s


def fluyt():
    s = Spr()
    hull(s, 3, 28, 18, stern=[0, 0, 0, 1, 1, 2, 4], bow=[2, 1, 1, 1, 2, 4, 6], line=3)
    castle(s, 3, 7, 14, 17)
    s.rect(28, 16, 31, 16, MAST)
    square_rig(s, 13, [(3, 6), (8, 15)], 3)
    square_rig(s, 22, [(5, 8), (10, 15)], 3)
    jib(s, 26, 6, 31, 15)
    s.line(5, 6, 5, 13, MAST)                     # lateen mizzen
    for y in range(8, 13):
        s.rect(6, y, 6 + (y - 8) // 2, y, SS)
    flagpole_flag(s, 3, 11)
    s.outline()
    return s


def brig():
    s = Spr()
    hull(s, 4, 26, 19, stern=[0, 0, 1, 2, 4], bow=[1, 1, 2, 3, 5], line=2)
    castle(s, 4, 7, 16, 18, windows=False)
    s.rect(26, 18, 30, 18, MAST)
    square_rig(s, 12, [(5, 8), (10, 16)], 3)
    square_rig(s, 20, [(6, 9), (11, 16)], 2)
    jib(s, 23, 7, 30, 17)
    s.outline()
    for x in range(9, 24, 3):        # marines on deck
        s.put(x, 18, SAIL)
    return s


# ================================================================ Empires Front (2026-11-06): every era
# its own ships (the styles above were shared by two or three eras)

# ---------------------------------------------------------------- Greece: rowed into battle, sail ashore
def greek_trireme():
    s = Spr()
    hull(s, 3, 27, 17, stern=[2, 1, 1, 2, 3, 5], bow=[2, 1, 1, 1, 2, 3], line=2)
    # tall curled stern (aphlaston), arching forward
    s.rect(3, 13, 4, 16, H)
    s.put(4, 12, HL); s.put(5, 11, HL); s.put(6, 11, TRIM); s.put(6, 12, TRIM)
    # outrigger box (parexeiresia) of the top bank and its oar ports
    s.rect(8, 16, 24, 16, HL)
    for x in range(9, 24, 2):
        s.put(x, 19, WIN)
    # bronze ram, painted eye, curved stem
    s.rect(27, 21, 30, 21, HL); s.put(31, 21, TRIM); s.put(30, 20, H)
    eye(s, 24, 18)
    s.put(27, 16, HL); s.put(28, 15, TRIM)
    # mast lowered for battle: a stump and a crested helmsman's awning
    s.rect(6, 14, 9, 15, DECK); s.rect(6, 14, 9, 14, TRIM)
    for x in range(11, 24, 3):     # hoplites' crests along the deck
        s.put(x, 15, SAIL); s.put(x + 1, 14, TRIM)
    s.outline()
    # three banks of oars
    for row, y in enumerate((23, 24, 25)):
        for x in range(6 + row, 26, 3):
            for k in range(3):
                s.late(x - k // 2, y + k - 1, MAST if k == 2 else O)
    return s


def holkas():
    s = Spr()
    hull(s, 3, 27, 18, stern=[0, 0, 1, 2, 3, 5, 7], bow=[1, 0, 1, 2, 3, 5, 7], line=3)
    s.rect(3, 15, 4, 17, H); s.put(3, 14, TRIM); s.put(2, 13, TRIM)    # goose-neck stern
    s.line(27, 17, 29, 14, HL); s.put(29, 13, TRIM)                     # stem
    mast(s, 15, 1, 17)
    sail(s, 8, 2, 22, 13, belly=3, bands=(5, 9), emblem="disc")
    s.line(5, 18, 2, 23, MAST)                                          # steering oar
    for x in (9, 12, 19):                                               # amphorae on deck
        s.rect(x, 16, x + 1, 17, DECK); s.put(x, 15, HL)
    s.outline()
    return s


def penteconter():
    s = Spr()
    hull(s, 4, 26, 19, stern=[1, 1, 2, 4], bow=[1, 1, 2, 3], line=2)
    s.rect(4, 15, 5, 18, H); s.put(5, 14, TRIM); s.put(6, 14, TRIM)
    s.rect(26, 21, 29, 21, HL)
    eye(s, 23, 20)
    mast(s, 15, 6, 18)
    sail(s, 11, 7, 19, 13, belly=1, bands=(10,))
    for x in range(7, 24, 3):     # round hoplite shields along the rail
        s.rect(x, 17, x + 1, 18, SAIL); s.put(x, 17, SS)
    s.outline()
    oars(s, range(7, 25), 23, step=2, length=4)
    return s


# ---------------------------------------------------------------- the Mongols: Yuan junks
def yuan_war_junk():
    s = Spr()
    hull(s, 1, 28, 19, stern=[0, 0, 0, 1, 2, 4], bow=[2, 1, 2, 3, 5, 7], line=2)
    # armoured bulwark with a row of round shields
    s.rect(4, 16, 24, 18, H); s.rect(4, 16, 24, 16, TRIM)
    for x in range(6, 24, 3):
        s.rect(x, 17, x + 1, 18, HL)
    castle(s, 1, 6, 13, 18, windows=True)
    # one great fan sail
    junk_sail(s, 18, 2, 15, 4, 9, step=3, fore=2)
    # horse-tail standard (tug) at the stern
    mast(s, 3, 3, 12)
    s.put(2, 2, TRIM); s.put(3, 2, TRIM); s.put(4, 2, TRIM); s.put(3, 1, TRIM)
    s.rect(4, 4, 5, 8, SS); s.put(4, 9, SD)
    s.outline()
    return s


def ger_barge():
    s = Spr()
    hull(s, 2, 28, 19, stern=[0, 0, 1, 2, 4], bow=[0, 0, 1, 2, 4], strakes=True, line=None)
    # a ger on deck: felt dome with a crown ring
    for y, (a, b) in enumerate(((10, 15), (8, 17), (7, 18), (7, 18), (7, 18), (7, 18))):
        for x in range(a, b + 1):
            s.put(x, 12 + y, SAIL if y < 2 else (SS if x == b else SAIL))
    s.rect(11, 11, 14, 11, TRIM)
    s.rect(7, 15, 18, 15, SD)
    s.rect(11, 16, 13, 18, WIN)                      # door
    junk_sail(s, 24, 4, 15, 2, 5, step=3)
    mast(s, 24, 16, 18)
    s.outline()
    return s


def horse_junk():
    s = Spr()
    hull(s, 3, 27, 19, stern=[0, 0, 1, 3, 5], bow=[1, 1, 2, 4, 6])
    castle(s, 3, 7, 16, 18, windows=False)
    junk_sail(s, 21, 4, 16, 3, 6, step=3)
    mast(s, 21, 17, 18)
    # horses' heads over the rail
    for x in (10, 15):
        s.rect(x, 15, x + 2, 18, HL)
        s.rect(x + 2, 14, x + 3, 15, HL)
        s.put(x + 1, 14, TRIM)
    s.outline()
    return s


# ---------------------------------------------------------------- Mali: the Niger
def niger_war_dhow():
    s = Spr()
    hull(s, 2, 28, 19, stern=[1, 0, 1, 2, 4, 6], bow=[0, 1, 3, 4, 6, 8], line=2)
    s.line(1, 18, 3, 20, HL)
    lateen(s, (25, 16), (6, 2), (7, 16))
    mast(s, 15, 3, 18)
    for x in range(6, 26, 3):     # spearmen and their tall shields
        s.rect(x, 16, x, 18, HL); s.put(x, 15, TRIM)
        s.rect(x + 1, 13, x + 1, 15, MAST)
    s.outline()
    return s


def pinasse():
    s = Spr()
    hull(s, 2, 29, 19, stern=[0, 0, 1, 3], bow=[0, 0, 1, 3], strakes=False, line=1)
    s.put(1, 18, TRIM); s.put(0, 17, TRIM); s.put(30, 18, TRIM); s.put(31, 17, TRIM)
    # arched mat canopies
    for (a, b) in ((6, 14), (16, 24)):
        for x in range(a, b + 1):
            t = (x - a) / (b - a)
            top = 10 + round(4 * (2 * t - 1) ** 2)
            for y in range(top, 19):
                s.put(x, y, SS if y == top or (x - a) % 3 == 0 else SAIL)
        s.rect(a, 18, b, 18, DECK)
    s.rect(15, 16, 15, 18, HL)                       # salt slabs between them
    s.outline()
    s.line(27, 18, 30, 25, MAST)                     # punting pole
    return s


def river_canoe():
    s = Spr()
    hull(s, 2, 29, 20, stern=[0, 0, 2, 4], bow=[0, 0, 2, 4], strakes=False, line=1)
    s.put(1, 19, TRIM); s.put(30, 19, TRIM)
    for x in range(5, 27, 3):     # paddlers in white caps
        s.rect(x, 17, x + 1, 19, HL); s.put(x, 16, SAIL); s.put(x + 1, 16, SAIL)
    s.outline()
    for x in range(5, 27, 3):
        s.line(x - 1, 20, x - 3, 25, MAST)
    return s


# ---------------------------------------------------------------- the Inca: balsa and totora
def war_raft():
    s = Spr()
    for y, (a, b) in enumerate(((2, 28), (1, 29), (2, 28))):
        for x in range(a, b + 1):
            s.put(x, 20 + y, HL if y == 0 else (H if x % 3 else HD))
    s.line(13, 19, 16, 2, MAST)
    s.line(19, 19, 16, 2, MAST)
    sail(s, 9, 4, 23, 15, belly=2, bands=(8,), emblem="cross")
    for x in range(4, 28, 3):     # warriors with star-headed maces
        if 11 <= x <= 21:
            continue
        s.rect(x, 17, x, 19, HL); s.put(x, 16, TRIM)
        s.put(x + 1, 15, SAIL); s.rect(x + 1, 16, x + 1, 18, MAST)
    for x in (7, 16, 25):
        s.rect(x, 23, x, 25, MAST)
    s.outline()
    return s


def totora():
    s = Spr()
    # reed bundle: deep in the middle, horns curling up at both ends
    for x in range(3, 29):
        t = abs(x - 16) / 13
        top = 19 - round(5 * t ** 3)
        for y in range(top, 22):
            s.put(x, y, HL if y == top else (SS if (x + y) % 4 == 0 else H))
    s.put(2, 13, TRIM); s.put(29, 13, TRIM)
    for x in range(6, 26, 4):     # lashings
        s.rect(x, 18, x, 21, HD)
    for x in range(8, 24, 4):     # rowers
        s.rect(x, 15, x + 1, 17, HL); s.put(x, 14, TRIM)
    s.outline()
    for x in range(8, 24, 4):
        s.line(x - 1, 21, x - 3, 26, MAST)
    return s


# ---------------------------------------------------------------- the Aztecs: Lake Texcoco
def cargo_acalli():
    s = Spr()
    hull(s, 3, 28, 19, stern=[0, 0, 2, 4], bow=[0, 0, 2, 4], strakes=False, line=1)
    s.put(2, 18, TRIM); s.put(29, 18, TRIM)
    # baskets of maize, cacao and cloth
    for x, h in ((7, 3), (11, 4), (15, 3), (19, 4)):
        s.rect(x, 18 - h, x + 2, 18, SAIL)
        s.rect(x, 18 - h, x + 2, 18 - h, SS)
        s.put(x + 1, 17 - h, TRIM)
    # the boatman with his pole
    s.rect(24, 13, 25, 18, HL); s.put(24, 12, TRIM); s.put(25, 11, SAIL)
    s.outline()
    s.line(27, 9, 21, 26, MAST)
    return s


# ---------------------------------------------------------------- steam: Russia 1914, Britain 1897
def funnel(s, x0, x1, y0, y1, band=None):
    s.rect(x0, y0, x1, y1, HL)
    s.rect(x0, y0, x1, y0, WIN)
    if band is not None:
        s.rect(x0, band, x1, band, TRIM)


def turret(s, x, y, face=1, guns=2):
    s.rect(x - 2, y, x + 2, y + 2, H)
    s.rect(x - 2, y, x + 2, y, HL)
    for g in range(guns):
        s.rect(x + 3 * face if face > 0 else x - 6, y + g, x + 6 if face > 0 else x - 3, y + g, MAST)


def dreadnought():
    s = Spr()
    hull(s, 1, 29, 18, stern=[1, 0, 0, 1, 2, 3], bow=[0, 0, 1, 2, 3, 4], strakes=False, line=2)
    s.rect(2, 19, 28, 19, HL)
    # low superstructure, two funnels, pole masts
    s.rect(10, 14, 21, 17, H); s.rect(10, 14, 21, 14, HL)
    for x in range(11, 21, 2):
        s.put(x, 16, WIN)
    funnel(s, 12, 13, 8, 13, band=10)
    funnel(s, 17, 18, 8, 13, band=10)
    mast(s, 9, 3, 13); s.rect(8, 4, 10, 4, MAST)
    mast(s, 22, 4, 13); s.rect(21, 5, 23, 5, MAST)
    # four triple turrets in line
    turret(s, 5, 15, face=-1, guns=2)
    turret(s, 25, 15, face=1, guns=2)
    s.rect(7, 16, 8, 17, H); s.rect(23, 16, 24, 17, H)
    pennant(s, 22, 2, 3)
    s.outline()
    return s


def cargo_steamer():
    s = Spr()
    hull(s, 2, 28, 18, stern=[0, 0, 0, 1, 2, 4], bow=[1, 0, 1, 2, 3, 5], strakes=True, line=None)
    s.rect(13, 13, 18, 17, H); s.rect(13, 13, 18, 13, HL)       # bridge house amidships
    s.put(14, 15, WIN); s.put(16, 15, WIN)
    funnel(s, 15, 16, 7, 12, band=9)
    for xm in (7, 24):                                         # masts with cargo derricks
        mast(s, xm, 4, 17)
        s.line(xm, 6, xm + (3 if xm < 15 else -3), 14, ROPE)
        s.rect(xm - 2, 15, xm + 2, 17, DECK)                   # hatch and crates
        s.rect(xm - 2, 15, xm + 2, 15, HL)
    s.rect(2, 15, 4, 17, H)                                    # poop
    s.outline()
    return s


def troopship():
    s = Spr()
    hull(s, 1, 29, 18, stern=[0, 0, 0, 1, 2, 3], bow=[0, 0, 1, 2, 3, 4], strakes=False)
    for x in range(3, 27, 2):                                  # portholes
        s.put(x, 20, WIN)
    s.rect(5, 13, 25, 17, SAIL); s.rect(5, 13, 25, 13, SS)    # white decks
    for x in range(6, 25, 2):
        s.put(x, 15, WIN)
    s.rect(9, 11, 21, 12, SAIL)
    funnel(s, 11, 13, 5, 10, band=7)
    funnel(s, 17, 19, 5, 10, band=7)
    mast(s, 4, 3, 12); mast(s, 26, 3, 12)
    s.outline()
    return s


def ironclad():
    s = Spr()
    hull(s, 1, 28, 18, stern=[1, 0, 0, 0, 1, 2], bow=[0, 0, 0, 1, 2, 3], strakes=False, line=2)
    s.rect(28, 21, 30, 22, HD); s.put(31, 22, H)               # ram bow
    s.rect(9, 14, 20, 17, H); s.rect(9, 14, 20, 14, HL)
    for x in range(10, 20, 2):
        s.put(x, 16, WIN)
    funnel(s, 12, 13, 8, 13, band=10)
    funnel(s, 16, 17, 8, 13, band=10)
    # military masts with fighting tops
    for xm in (6, 23):
        mast(s, xm, 3, 15)
        s.rect(xm - 1, 6, xm + 1, 7, H)
        s.rect(xm - 2, 3, xm + 2, 3, MAST)
    turret(s, 4, 15, face=-1, guns=1)
    turret(s, 25, 15, face=1, guns=1)
    pennant(s, 23, 1, 3)
    s.outline()
    return s


def steam_clipper():
    s = Spr()
    hull(s, 2, 27, 18, stern=[0, 0, 0, 1, 2, 4], bow=[2, 1, 1, 2, 3, 5], line=2)
    s.rect(27, 17, 31, 17, MAST)
    square_rig(s, 9, [(4, 7), (9, 15)], 3)
    square_rig(s, 21, [(5, 8), (10, 15)], 3)
    funnel(s, 14, 15, 9, 16, band=11)                          # an auxiliary engine's funnel
    jib(s, 24, 6, 31, 16)
    s.outline()
    return s


def liner():
    s = Spr()
    hull(s, 1, 29, 18, stern=[0, 0, 0, 1, 2, 3], bow=[1, 0, 1, 2, 3, 4], strakes=False, line=2)
    s.rect(6, 14, 24, 17, SAIL); s.rect(6, 14, 24, 14, SS)
    for x in range(7, 24, 2):
        s.put(x, 16, WIN)
    funnel(s, 14, 16, 6, 13, band=8)
    for xm in (5, 26):                                         # two masts, still rigged
        mast(s, xm, 2, 17)
        s.rect(xm - 2, 5, xm + 2, 5, MAST)
    s.outline()
    return s


SETS = {
    "ancient": {"warship": trireme, "trade": corbita, "transport": liburna},
    "greek": {"warship": greek_trireme, "trade": holkas, "transport": penteconter},
    "dhow": {"warship": baghlah, "trade": boom, "transport": sambuk},
    "niger": {"warship": niger_war_dhow, "trade": pinasse, "transport": river_canoe},
    "galley": {"warship": kadirga, "trade": mavna, "transport": firkate},
    "junk": {"warship": fuchuan, "trade": shachuan, "transport": troop_junk},
    "yuan": {"warship": yuan_war_junk, "trade": ger_barge, "transport": horse_junk},
    "japan": {"warship": atakebune, "trade": bezaisen, "transport": sekibune},
    "canoe": {"warship": war_canoe, "trade": cargo_acalli, "transport": dugout},
    "raft": {"warship": war_raft, "trade": balsa_raft, "transport": totora},
    "steam": {"warship": dreadnought, "trade": cargo_steamer, "transport": troopship},
    "victorian": {"warship": ironclad, "trade": steam_clipper, "transport": liner},
    "sail": {"warship": ship_of_line, "trade": fluyt, "transport": brig},
}


def tint(im, rgb):
    out = Image.new("RGBA", im.size)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            out.putpixel((x, y), (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, a))
    return out


def rle(r):
    """Runs of 3 or more of a letter as <count><letter> ("12.3A" = 12 clear, 3 A)."""
    out, i = "", 0
    while i < len(r):
        j = i
        while j < len(r) and r[j] == r[i]:
            j += 1
        out += (str(j - i) + r[i]) if j - i >= 3 else r[i] * (j - i)
        i = j
    return out


def main(out, preview=None):
    """Writes the sprites as rows of palette letters ("." clear; each letter one grey), 32 x 32."""
    rows = []
    sprites = {}
    greys = set()
    for style, ships in SETS.items():
        row = []
        for kind, fn in ships.items():
            im = fn().image()
            row.append(im)
            sprites[(style, kind)] = im
            for y in range(N):
                for x in range(N):
                    r, g, b, a = im.getpixel((x, y))
                    if a:
                        greys.add(r)
        rows.append(row)
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    greys = sorted(greys)
    assert len(greys) <= len(letters), len(greys)
    code = {v: letters[i] for i, v in enumerate(greys)}
    lines = ["-- GENERATED by tools/make_ships.py: ship sprites (grey-scale, %d x %d), by era style: rows of" % (N, N),
             "-- palette letters (\".\" clear), each letter one grey (`palette`, 0..255), tinted with the owner's colour;",
             "-- runs of 3 or more are written <count><letter> (Map/ShipArt unpacks them).",
             "return {", "\tsize = %d," % N, "\tpalette = {"]
    for v in greys:
        lines.append("\t\t%s = %d," % (code[v], v))
    lines.append("\t},")
    for style, ships in SETS.items():
        lines.append("\t%s = {" % style)
        for kind in ships:
            im = sprites[(style, kind)]
            lines.append("\t\t%s = {" % kind)
            for y in range(N):
                r = ""
                for x in range(N):
                    pr, pg, pb, pa = im.getpixel((x, y))
                    r += code[pr] if pa else "."
                lines.append('\t\t\t"%s",' % rle(r))
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    open(out, "w").write("\n".join(lines) + "\n")
    if preview:
        cols = [(230, 80, 70), (80, 170, 230), (240, 200, 70)]
        g = N + 6
        sheet = Image.new("RGBA", (g * 3 * len(cols) + 8, g * len(rows) + 4), (52, 104, 160, 255))
        for r, row in enumerate(rows):
            for ci, col in enumerate(cols):
                for k, im in enumerate(row):
                    sheet.alpha_composite(tint(im, col), (ci * (g * 3 + 4) + k * g + 3, r * g + 3))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(preview)


if __name__ == "__main__":
    args = sys.argv[1:]
    pv = None
    if "--preview" in args:
        i = args.index("--preview")
        pv = args[i + 1]
        del args[i:i + 2]
    main(args[0], pv)
