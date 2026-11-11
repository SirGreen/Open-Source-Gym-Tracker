"""Generates the launcher icons from code so they can be tweaked and redone.

The mark is the app's initial, drawn as one heavy chalk stroke.

    python tool/make_icons.py

Writes legacy, round, adaptive-foreground and themed-monochrome layers for
every density, plus a 1024 master under assets/icon/.
"""

import math
import os
from PIL import Image, ImageDraw

SS = 8  # supersample factor — PIL does not antialias its own drawing

GREEN_TOP = (82, 227, 133)
GREEN_BOT = (0, 176, 74)
BG_TOP = (23, 51, 33)
BG_BOT = (7, 13, 9)

# How much of the canvas the C spans. The legacy PNG is a plain square,
# but a launcher shows only the middle 72dp of the 108dp adaptive canvas, so
# the adaptive layers need a smaller fraction to end up the same size on
# screen. 0.38 x 108dp = 41dp, well inside the 66dp safe zone.
LEGACY_MARK = 0.54
ADAPTIVE_MARK = 0.50

RES = 'android/app/src/main/res'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def vgrad(size, top, bot):
    w, h = size
    strip = Image.new('RGB', (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bot))
    return strip.resize((w, h), Image.BICUBIC)


def _stroke(d, p0, p1, w):
    """A chalk stroke: a line with round caps."""
    d.line([p0, p1], fill=255, width=int(w), joint='curve')
    for x, y in (p0, p1):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)


def mark_mask(canvas, width_frac):
    """Alpha mask of the C, centred, spanning width_frac of the canvas.

    One heavy chalk stroke closing into the app's initial. Round terminals so
    it reads as drawn rather than cut, and a gap wide enough that it stays a C
    at 48 px instead of a ring with a nick in it.

    Built as an annulus with a wedge removed rather than a thick polyline:
    PIL's curve joints leave slivers along the outside of a stroke this heavy.
    """
    n = canvas * SS
    m = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(m)
    cx = cy = n / 2
    u = (width_frac * n) / 2  # half the mark's width, in pixels

    weight = 0.40 * u          # stroke thickness
    r = u - weight / 2         # centreline radius, so the stroke ends at u
    gap = 74                   # degrees of opening, on the right

    outer, inner = r + weight / 2, r - weight / 2
    d.ellipse([cx - outer, cy - outer, cx + outer, cy + outer], fill=255)
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=0)
    pad = outer + 4
    d.pieslice([cx - pad, cy - pad, cx + pad, cy + pad],
               -gap / 2, gap / 2, fill=0)

    for angle in (-gap / 2, gap / 2):
        px = cx + r * math.cos(math.radians(angle))
        py = cy + r * math.sin(math.radians(angle))
        d.ellipse([px - weight / 2, py - weight / 2,
                   px + weight / 2, py + weight / 2], fill=255)

    return m.resize((canvas, canvas), Image.LANCZOS)


def shape_mask(canvas, round_):
    n = canvas * SS
    m = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(m)
    if round_:
        d.ellipse([0, 0, n - 1, n - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, n - 1, n - 1], radius=0.22 * n, fill=255)
    return m.resize((canvas, canvas), Image.LANCZOS)


def marked(canvas, width_frac):
    """The green dumbbell on transparency."""
    img = vgrad((canvas, canvas), GREEN_TOP, GREEN_BOT).convert('RGBA')
    img.putalpha(mark_mask(canvas, width_frac))
    return img


def full_icon(canvas, round_):
    bg = vgrad((canvas, canvas), BG_TOP, BG_BOT).convert('RGBA')
    bg.alpha_composite(marked(canvas, LEGACY_MARK))
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    out.paste(bg, (0, 0), shape_mask(canvas, round_))
    return out


def monochrome(canvas, width_frac):
    """Flat white silhouette — Android 13 tints it to the user's theme."""
    alpha = mark_mask(canvas, width_frac)
    img = Image.new('RGBA', (canvas, canvas), (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def status_icon(px):
    """Status-bar icon: a white silhouette on transparency, 24dp of glyph.

    Android tints these by alpha, so only the shape matters.
    """
    return monochrome(px, 0.86)


def main():
    for name, scale in DENSITIES.items():
        out = os.path.join(RES, 'mipmap-' + name)
        os.makedirs(out, exist_ok=True)
        legacy = round(48 * scale)
        adaptive = round(108 * scale)
        full_icon(legacy, False).save(os.path.join(out, 'ic_launcher.png'))
        full_icon(legacy, True).save(os.path.join(out, 'ic_launcher_round.png'))
        marked(adaptive, ADAPTIVE_MARK).save(
            os.path.join(out, 'ic_launcher_foreground.png'))
        monochrome(adaptive, ADAPTIVE_MARK).save(
            os.path.join(out, 'ic_launcher_monochrome.png'))

        # The notification / Live Update icon lives in drawable, at 24dp.
        drawable = os.path.join(RES, 'drawable-' + name)
        os.makedirs(drawable, exist_ok=True)
        status_icon(round(24 * scale)).save(
            os.path.join(drawable, 'ic_stat_chalk.png'))
        print(f'{name}: {legacy}px legacy, {adaptive}px adaptive')

    os.makedirs('assets/icon', exist_ok=True)
    full_icon(1024, False).save('assets/icon/app_icon.png')
    marked(1024, ADAPTIVE_MARK).save('assets/icon/app_icon_foreground.png')
    print('master: assets/icon/app_icon.png')


if __name__ == '__main__':
    main()
