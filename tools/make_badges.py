"""Empires Front: 512 x 512 badge images (one per achievement) for the Roblox Creator Dashboard: a medal in
the achievement's metal with its glyph, framed for Roblox's round badge crop."""
import importlib.util, os, re, sys
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("make_icons", os.path.join(HERE, "make_icons.py"))
mi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mi)

TIERS = {"bronze": ((232, 160, 90), (150, 82, 30)), "silver": ((236, 242, 250), (140, 152, 170)),
         "gold": ((255, 222, 110), (196, 130, 20))}
ICON_FN = {"city": mi.temple, "mine": mi.mine, "market": mi.market, "pact_trade": mi.trade_pact,
           "pact_defense": mi.defense_pact, "forge": mi.forge, "warship": mi.ship, "sword": mi.sword,
           "ore": mi.ore, "crown": mi.crown, "laurel": mi.laurel}
BG = (22, 26, 40)


def badge(icon, tier):
    S = 512
    hi, lo = TIERS[tier]
    im = Image.new("RGBA", (S, S), BG + (255,))
    d = ImageDraw.Draw(im)
    # radial-ish disc: concentric rings from lo to hi
    for k in range(200, 0, -1):
        t = k / 200
        c = tuple(int(lo[i] * t + hi[i] * (1 - t)) for i in range(3))
        r = 60 + k * 0.95
        d.ellipse([S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r], fill=c)
    d.ellipse([56, 56, S - 56, S - 56], outline=(60, 38, 8), width=10)
    d.ellipse([84, 84, S - 84, S - 84], outline=tuple(int(v * 0.8) for v in lo), width=4)
    # glyph (white mask) tinted dark, with a light emboss
    m = ICON_FN[icon]().resize((260, 260), Image.LANCZOS)
    shadow = Image.new("RGBA", (260, 260), (255, 255, 255, 0))
    shadow.putalpha(m.point(lambda v: int(v * 0.5)))
    im.alpha_composite(shadow, (126 + 4, 126 + 6))
    glyph = Image.new("RGBA", (260, 260), (60, 38, 8, 0))
    glyph.putalpha(m)
    im.alpha_composite(glyph, (126, 126))
    return im.convert("RGB")


def main(ach_luau, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    s = open(ach_luau).read()
    for m in re.finditer(r'\{ id = "([^"]+)", title = "([^"]+)", text = "[^"]*", icon = "([^"]+)", tier = "([^"]+)"', s):
        aid, title, icon, tier = m.groups()
        badge(icon, tier).save(os.path.join(out_dir, "%s.png" % aid))
        print(aid, title)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
