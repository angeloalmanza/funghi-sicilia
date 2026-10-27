"""Disegna l'icona dell'app (fungo) con Pillow.
Output: app/assets/icon/icon.png (completa, angoli arrotondati) e icon_fg.png (adaptive, trasparente).
Poi: cd app && dart run flutter_launcher_icons
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "icon"
OUT.mkdir(parents=True, exist_ok=True)

S = 1024
K = 3  # supersampling
BG = (31, 59, 45, 255)        # verde bosco
CAP = (205, 62, 40, 255)      # cappello
CAP_DARK = (150, 38, 28, 255)
STEM = (243, 235, 214, 255)
STEM_SH = (214, 201, 170, 255)
GILL = (232, 214, 178, 255)


def mushroom(size, scale=1.0):
    """Fungo centrato in un riquadro `size`; `scale` 1.0 = occupa ~500/1024 dell'altezza."""
    import math
    w = h = size * K
    u = w / 1024 * scale
    cx = w / 2

    def P(x, y):  # coordinate di disegno (riquadro 500x500 centrato)
        return (cx + (x - 250) * u, h / 2 + (y - 250) * u)

    def box(x0, y0, x1, y1):
        a, b = P(x0, y0)
        c, e = P(x1, y1)
        return [a, b, c, e]

    def layer():
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        return im, ImageDraw.Draw(im)

    out, _ = layer()

    # gambo: profilo liscio, rastremato verso l'alto, base a bulbo
    def half(y):
        t = (y - 240) / (490 - 240)
        return 58 + 34 * (t ** 3) - 10 * math.sin(math.pi * min(t, 1) * 0.9) * 0.5
    ys = [240 + i * 5 for i in range(0, 51)]
    pts = [P(250 - half(y), y) for y in ys] + [P(250 + half(y), y) for y in reversed(ys)]
    stem, sd = layer()
    sd.polygon(pts, fill=STEM)
    sd.ellipse(box(250 - half(490), 478, 250 + half(490), 506), fill=STEM)
    out.alpha_composite(stem)
    # ombra sul lato destro del gambo (sfumata, ritagliata sul gambo)
    sh, shd = layer()
    shd.ellipse(box(262, 230, 400, 520), fill=STEM_SH)
    sh = sh.filter(ImageFilter.GaussianBlur(14 * u))
    clip = stem.getchannel("A")
    sh.putalpha(Image.eval(Image.composite(sh.getchannel("A"), Image.new("L", (w, h), 0), clip), lambda v: v))
    out.alpha_composite(sh)
    # ombra proiettata del cappello sul gambo
    cs, csd = layer()
    csd.ellipse(box(120, 215, 380, 290), fill=(120, 95, 60, 150))
    cs = cs.filter(ImageFilter.GaussianBlur(10 * u))
    cs.putalpha(Image.composite(cs.getchannel("A"), Image.new("L", (w, h), 0), clip))
    out.alpha_composite(cs)

    # lamelle sotto il cappello
    g, gd = layer()
    gd.ellipse(box(35, 205, 465, 270), fill=GILL)
    out.alpha_composite(g)
    # cappello
    cap, cd = layer()
    cd.pieslice(box(0, 20, 500, 440), 180, 360, fill=CAP)
    cd.ellipse(box(0, 200, 500, 250), fill=CAP)
    out.alpha_composite(cap)
    capmask = cap.getchannel("A")
    # volume: bordo scuro in basso e luce in alto a sinistra
    dk, dkd = layer()
    dkd.ellipse(box(-50, -230, 550, 232), outline=CAP_DARK, width=int(44 * u))
    dk = dk.filter(ImageFilter.GaussianBlur(14 * u))
    dk.putalpha(Image.composite(dk.getchannel("A"), Image.new("L", (w, h), 0), capmask))
    out.alpha_composite(dk)
    hl, hld = layer()
    hld.ellipse(box(60, 50, 270, 140), fill=(255, 150, 120, 120))
    hl = hl.filter(ImageFilter.GaussianBlur(22 * u))
    hl.putalpha(Image.composite(hl.getchannel("A"), Image.new("L", (w, h), 0), capmask))
    out.alpha_composite(hl)
    # puntini
    sp, spd = layer()
    for (x, y, r, ry) in [(250, 70, 36, 24), (120, 140, 28, 19), (385, 130, 32, 22), (55, 200, 18, 11), (448, 198, 18, 11), (250, 160, 22, 15), (190, 100, 14, 9)]:
        spd.ellipse(box(x - r, y - ry, x + r, y + ry), fill=(255, 255, 255, 255))
    out.alpha_composite(sp)
    return out.resize((size, size), Image.LANCZOS)


# icona completa (legacy / anteprima)
full = Image.new("RGBA", (S, S), BG)
full.alpha_composite(mushroom(S, 1.3))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=220, fill=255)
rounded = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rounded.paste(full, (0, 0), mask)
rounded.save(OUT / "icon.png")

# adaptive: solo primo piano, dentro la safe zone (~66%)
fg = mushroom(S, 1.1)
fg.save(OUT / "icon_fg.png")
print("icone scritte in", OUT)
