"""Empires Front UI glyphs: white masks drawn at 4x and downsampled (antialiased alpha), 48 x 48.
Writes PNG previews and the Luau data (base64 of the alpha bytes) for client/UI/PixelIcons."""
import base64, math, sys
from PIL import Image, ImageDraw

S = 192  # draw size
N = 48   # final size


def canvas():
    im = Image.new("L", (S, S), 0)
    return im, ImageDraw.Draw(im)


def temple():
    im, d = canvas()
    d.polygon([(20, 62), (96, 18), (172, 62)], fill=255)            # pediment
    d.polygon([(44, 54), (96, 30), (148, 54)], fill=0)               # pediment hollow
    d.rectangle([22, 66, 170, 80], fill=255)                         # entablature
    for x in (34, 68, 104, 138):
        d.rectangle([x, 86, x + 20, 150], fill=255)                  # columns
        d.rectangle([x - 4, 82, x + 24, 88], fill=255)               # capitals
    d.rectangle([18, 152, 174, 162], fill=255)                       # steps
    d.rectangle([8, 166, 184, 178], fill=255)
    return im


def wagon():
    im, d = canvas()
    d.polygon([(18, 64), (174, 64), (160, 118), (32, 118)], fill=255)   # body
    d.rectangle([30, 76, 162, 82], fill=0)
    d.rectangle([28, 92, 164, 98], fill=0)
    d.line([(174, 96), (190, 110)], fill=255, width=10)                 # shaft
    for cx in (58, 136):
        d.ellipse([cx - 32, 110, cx + 32, 174], fill=255)
        d.ellipse([cx - 22, 120, cx + 22, 164], fill=0)
        for a in range(0, 180, 45):
            r = math.radians(a)
            dx, dy = 22 * math.cos(r), 22 * math.sin(r)
            d.line([(cx - dx, 142 - dy), (cx + dx, 142 + dy)], fill=255, width=7)
        d.ellipse([cx - 8, 134, cx + 8, 150], fill=255)
    return im


def forge():
    im, d = canvas()
    # anvil
    d.polygon([(14, 92), (150, 92), (176, 80), (176, 98), (150, 116), (126, 116), (112, 132),
               (112, 148), (138, 160), (138, 176), (52, 176), (52, 160), (78, 148), (78, 132),
               (58, 116), (30, 116)], fill=255)
    # hammer, tilted, above
    d.polygon([(96, 20), (150, 48), (140, 66), (86, 38)], fill=255)      # head
    d.line([(118, 52), (70, 84)], fill=255, width=12)                     # handle
    # sparks
    for x, y in ((40, 60), (58, 40), (28, 76)):
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=255)
    return im


def mine():
    im, d = canvas()
    # rock pile
    d.polygon([(10, 178), (40, 120), (78, 140), (112, 104), (150, 132), (182, 178)], fill=255)
    d.polygon([(52, 160), (70, 150), (84, 168)], fill=0)
    d.polygon([(118, 150), (134, 142), (146, 164)], fill=0)
    # pickaxe
    d.line([(52, 128), (150, 30)], fill=0, width=24)
    d.line([(54, 126), (148, 32)], fill=255, width=12)                       # handle
    d.arc([60, 4, 196, 110], start=200, end=320, fill=255, width=16)          # head
    return im


def market():
    im, d = canvas()
    d.rectangle([90, 26, 102, 160], fill=255)                 # post
    d.polygon([(60, 176), (132, 176), (110, 158), (82, 158)], fill=255)   # base
    d.ellipse([86, 14, 106, 34], fill=255)
    d.line([(22, 46), (170, 46)], fill=255, width=10)          # beam
    for cx in (40, 152):
        d.line([(cx, 50), (cx - 24, 112)], fill=255, width=5)
        d.line([(cx, 50), (cx + 24, 112)], fill=255, width=5)
        d.chord([cx - 34, 84, cx + 34, 140], start=0, end=180, fill=255)   # pans
    return im


def ore():
    im, d = canvas()
    pts = [(96, 18), (160, 62), (146, 150), (96, 178), (40, 150), (30, 62)]
    d.polygon(pts, fill=255)
    for a, b in (((96, 18), (96, 92)), ((30, 62), (96, 92)), ((160, 62), (96, 92)),
                 ((96, 92), (96, 178)), ((40, 150), (96, 92)), ((146, 150), (96, 92))):
        d.line([a, b], fill=0, width=7)
    return im


def pact():
    im, d = canvas()
    # scroll
    d.rectangle([40, 36, 150, 150], fill=255)
    d.ellipse([24, 22, 60, 58], fill=255)
    d.ellipse([132, 128, 168, 164], fill=255)
    d.ellipse([32, 30, 52, 50], fill=0)
    for y in (66, 86, 106):
        d.line([(62, y), (130, y)], fill=0, width=7)
    # seal
    d.ellipse([100, 112, 152, 164], fill=0)
    d.ellipse([108, 120, 144, 156], fill=255)
    d.polygon([(110, 158), (100, 186), (118, 176), (126, 158)], fill=255)
    d.polygon([(134, 158), (142, 186), (150, 172), (144, 156)], fill=255)
    return im


def ship():
    im, d = canvas()
    d.polygon([(8, 120), (184, 120), (162, 160), (36, 160)], fill=255)    # hull
    d.polygon([(184, 120), (192, 100), (178, 122)], fill=255)              # prow
    d.rectangle([92, 20, 100, 124], fill=255)                               # mast
    d.polygon([(46, 36), (146, 36), (152, 104), (40, 104)], fill=255)      # square sail
    d.line([(46, 70), (146, 70)], fill=0, width=5)
    for x in range(40, 170, 22):                                            # oars
        d.line([(x, 150), (x - 14, 184)], fill=255, width=6)
    return im


def handshake():
    im, d = canvas()
    # sleeves
    d.polygon([(4, 70), (52, 58), (66, 104), (16, 122)], fill=255)
    d.polygon([(188, 70), (140, 58), (126, 104), (176, 122)], fill=255)
    d.line([(10, 74), (56, 62)], fill=0, width=5)
    d.line([(182, 74), (136, 62)], fill=0, width=5)
    # joined hands
    d.rounded_rectangle([56, 64, 140, 128], radius=26, fill=255)
    for x in (78, 96, 114):
        d.line([(x, 70), (x + 10, 120)], fill=0, width=6)
    d.polygon([(60, 72), (96, 52), (112, 62), (80, 86)], fill=255)     # thumb
    d.line([(64, 76), (100, 58)], fill=0, width=5)
    return im


def dagger():
    im, d = canvas()
    d.polygon([(96, 6), (114, 40), (110, 120), (82, 120), (78, 40)], fill=255)   # blade
    d.line([(96, 20), (96, 112)], fill=0, width=6)
    d.rounded_rectangle([46, 118, 146, 134], radius=8, fill=255)                 # guard
    d.rectangle([86, 134, 106, 172], fill=255)                                   # grip
    d.ellipse([80, 166, 112, 192], fill=255)                                     # pommel
    # drop of blood
    d.polygon([(150, 140), (162, 162), (138, 162)], fill=255)
    d.ellipse([136, 152, 164, 180], fill=255)
    return im


def donate():
    im, d = canvas()
    # helmet (crested, ancient)
    d.chord([40, 30, 152, 140], start=180, end=360, fill=255)
    d.rectangle([40, 84, 152, 100], fill=255)
    d.rectangle([52, 100, 72, 140], fill=255)
    d.rectangle([120, 100, 140, 140], fill=255)
    d.polygon([(60, 30), (96, 4), (132, 30), (120, 40), (96, 22), (72, 40)], fill=255)  # crest
    d.rectangle([82, 100, 110, 112], fill=0)
    # arrow to the right
    d.rectangle([60, 156, 140, 170], fill=255)
    d.polygon([(136, 142), (170, 163), (136, 184)], fill=255)
    return im


def hourglass():
    im, d = canvas()
    d.rounded_rectangle([40, 14, 152, 32], radius=8, fill=255)
    d.rounded_rectangle([40, 160, 152, 178], radius=8, fill=255)
    d.polygon([(54, 32), (138, 32), (104, 96), (138, 160), (54, 160), (88, 96)], fill=255)
    d.polygon([(68, 44), (124, 44), (96, 88)], fill=0)
    d.polygon([(96, 112), (126, 150), (66, 150)], fill=0)
    d.polygon([(96, 124), (112, 148), (80, 148)], fill=255)
    return im


def trade_pact():
    im, d = canvas()
    # two coins stacked and a scroll band
    for cx, cy in ((70, 110), (122, 82)):
        d.ellipse([cx - 46, cy - 46, cx + 46, cy + 46], fill=255)
        d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=0)
        d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=255)
    d.rectangle([110, 66, 134, 98], fill=0)
    d.rectangle([116, 70, 128, 94], fill=255)
    d.rectangle([58, 94, 82, 126], fill=0)
    d.rectangle([64, 98, 76, 122], fill=255)
    d.rounded_rectangle([20, 150, 172, 176], radius=12, fill=255)
    return im


def defense_pact():
    im, d = canvas()
    # crossed swords behind a shield
    for a, b in (((22, 22), (170, 170)), ((170, 22), (22, 170))):
        d.line([a, b], fill=255, width=14)
    d.line([(34, 150), (58, 174)], fill=255, width=18)
    d.line([(158, 150), (134, 174)], fill=255, width=18)
    d.polygon([(96, 34), (150, 52), (146, 112), (96, 168), (46, 112), (42, 52)], fill=0)
    d.polygon([(96, 44), (140, 58), (136, 108), (96, 154), (56, 108), (52, 58)], fill=255)
    d.line([(96, 56), (96, 140)], fill=0, width=8)
    d.line([(62, 86), (130, 86)], fill=0, width=8)
    return im


def ore_arrow(out):
    def f():
        im = ore().resize((128, 128), Image.LANCZOS)
        base = Image.new("L", (S, S), 0)
        base.paste(im, (0, 32))
        d = ImageDraw.Draw(base)
        if out:
            d.rectangle([128, 88, 168, 104], fill=255)
            d.polygon([(162, 70), (192, 96), (162, 122)], fill=255)
        else:
            d.rectangle([150, 88, 190, 104], fill=255)
            d.polygon([(156, 70), (126, 96), (156, 122)], fill=255)
        return base
    return f

ICONS = {"city_era": temple, "road_era": wagon, "forge": forge, "mine": mine, "market": market,
         "ore": ore, "pact": pact, "ship_era": ship, "alliance": handshake, "betray": dagger,
         "donate": donate, "renew": hourglass, "pact_trade": trade_pact, "pact_defense": defense_pact,
         "ore_sell": ore_arrow(True), "ore_buy": ore_arrow(False)}


def main(out_luau):
    entries = []
    sheet = Image.new("RGBA", (N * len(ICONS), N), (30, 34, 48, 255))
    for i, (name, fn) in enumerate(ICONS.items()):
        a = fn().resize((N, N), Image.LANCZOS)
        rgba = Image.merge("RGBA", (a.point(lambda v: 255),) * 3 + (a,))
        sheet.alpha_composite(rgba, (i * N, 0))
        entries.append((name, base64.b64encode(a.tobytes()).decode()))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save("/home/claude/art2/sheet.png")
    with open(out_luau, "w") as f:
        f.write("-- GENERATED by tools/make_icons.py: alpha masks, %d x %d, base64.\nreturn {\n\tsize = %d,\n" % (N, N, N))
        for name, b in entries:
            f.write('\t%s = "%s",\n' % (name, b))
        f.write("}\n")


main(sys.argv[1])
