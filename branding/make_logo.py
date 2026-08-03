"""Turn the supplied PW logo into the assets the app and installer need.

Run:  python branding/make_logo.py

The source (image.png) is a screenshot: opaque white background, a black PW
monogram, a stray grey Google-Lens button in the bottom-left corner, and a
black bar down the right edge. All three artefacts have to go, the white has
to become transparent, and the mark is needed in white as well as black
because the app's start screen is dark by default - a black logo there is
invisible.
"""
import base64
import io
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "image.png")
OUT = os.path.join(HERE, "logo")
os.makedirs(OUT, exist_ok=True)


def clean(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size

    # Drop the right-hand black bar and the bottom-left button before doing
    # anything else, so neither can influence the crop box below.
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            in_right_bar = x > w - 12
            in_lens_button = x < int(w * 0.14) and y > h - int(h * 0.14)
            if in_right_bar or in_lens_button:
                px[x, y] = (255, 255, 255, 255)

    # White -> transparent, everything darker -> opaque, with the pixel's own
    # darkness kept as the alpha so the curves stay smooth rather than jagged.
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum < 250:
                op[x, y] = (0, 0, 0, 255 - lum)

    out = drop_specks(out)
    bbox = out.getchannel("A").getbbox()
    return out.crop(bbox) if bbox else out


def drop_specks(im, keep_ratio=0.05):
    """Discard components far smaller than the biggest one.

    Cropping the artefacts by coordinate leaves fragments behind - a stub of
    the right-hand bar survives near the bottom corner. Keeping only the
    single largest component would remove it, but it would also remove the
    outer ring, which is a separate component from the filled disc. So every
    component within `keep_ratio` of the largest is kept and the rest go.
    """
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    comps = []

    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if seen[i] or px[sx, sy][3] == 0:
                continue
            stack, comp = [(sx, sy)], []
            seen[i] = 1
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and px[nx, ny][3] != 0:
                            seen[j] = 1
                            stack.append((nx, ny))
            comps.append(comp)

    if not comps:
        return im
    cutoff = max(len(c) for c in comps) * keep_ratio

    keep = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    kp = keep.load()
    for comp in comps:
        if len(comp) >= cutoff:
            for x, y in comp:
                kp[x, y] = px[x, y]
    return keep


def recolour(im, rgb):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    op, ip = out.load(), im.load()
    for y in range(im.height):
        for x in range(im.width):
            a = ip[x, y][3]
            if a:
                op[x, y] = (rgb[0], rgb[1], rgb[2], a)
    return out


def square(im, pad_ratio=0.06):
    """Centre the mark on a transparent square so it scales predictably."""
    side = int(max(im.size) * (1 + pad_ratio * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    return canvas


def svg_wrapping(im, width, height):
    """SVG carrying the PNG inline, so it drops into the existing <img> slots."""
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return (
        '<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" fill="none" '
        'xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink">\n'
        '    <image width="{w}" height="{h}" preserveAspectRatio="xMidYMid meet" '
        'xlink:href="data:image/png;base64,{d}"/>\n'
        "</svg>\n"
    ).format(w=width, h=height, d=b64)


mark = square(clean(SRC))
mark.save(os.path.join(OUT, "pw-mark-black.png"))
recolour(mark, (255, 255, 255)).save(os.path.join(OUT, "pw-mark-white.png"))
print("cleaned mark: %dx%d" % mark.size)

# The start screen slots are 52x45; a square mark is letterboxed into them by
# preserveAspectRatio rather than stretched.
for name, rgb in (("light", (0, 0, 0)), ("dark", (255, 255, 255))):
    art = recolour(mark, rgb).resize((45, 45), Image.LANCZOS)
    with open(os.path.join(OUT, "idx-logo-%s.svg" % name), "w", encoding="utf-8") as f:
        f.write(svg_wrapping(art, 52, 45))
    print("wrote idx-logo-%s.svg" % name)


def app_tile(size):
    """The mark on a white rounded tile.

    The mark on its own is black, which disappears against a dark taskbar or
    a dark Explorer background. Sitting it on an opaque light tile keeps it
    legible everywhere, and matches how the logo is drawn on its own artwork.
    """
    from PIL import ImageDraw

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = max(1, size // 32)
    d.rounded_rectangle([pad, pad, size - pad, size - pad],
                        radius=max(2, size // 6), fill=(255, 255, 255, 255))
    inner = int(size * 0.74)
    art = mark.resize((inner, inner), Image.LANCZOS)
    img.paste(art, ((size - inner) // 2, (size - inner) // 2), art)
    return img


def _font(px, bold=True):
    from PIL import ImageFont
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")
    for n in names:
        try:
            return ImageFont.truetype(n, px)
        except OSError:
            continue
    return ImageFont.load_default()


def wordmark(width, height, ink):
    """The caption wordmark: monogram plus 'PW Docs', sized to the given box.

    The window caption uses an 85x20 strip with 1.25/1.5/1.75 DPI variants,
    so this is generated per size rather than scaled from one bitmap - text
    that small goes mushy when it is resampled.
    """
    from PIL import ImageDraw

    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    m = height
    art = recolour(mark, ink).resize((m, m), Image.LANCZOS)
    img.paste(art, (0, 0), art)

    f = _font(int(height * 0.72), bold=True)
    text = "PW Docs"
    bb = d.textbbox((0, 0), text, font=f)
    d.text((m + max(2, height // 5) - bb[0],
            (height - (bb[3] - bb[1])) / 2 - bb[1]),
           text, font=f, fill=ink + (255,))
    return img


# Caption strip, matching the sizes upstream ships. "light"/"dark" name the
# theme the asset is drawn for, so the light-theme one carries dark ink.
CAPTION = [("", 85, 20), ("@1.25x", 106, 25), ("@1.5x", 128, 30), ("@1.75x", 149, 35)]
for theme, ink in (("light", (68, 68, 68)), ("dark", (255, 255, 255))):
    for suffix, w, h in CAPTION:
        wordmark(w, h, ink).save(
            os.path.join(OUT, "logo_%s%s.png" % (theme, suffix)))
    with open(os.path.join(OUT, "logo_%s.svg" % theme), "w", encoding="utf-8") as f:
        f.write(svg_wrapping(wordmark(85 * 4, 20 * 4, ink), 85, 20))
    print("wrote logo_%s.svg + %d png variants" % (theme, len(CAPTION)))


def splash(width=500, height=250):
    """Startup splash, matching the 500x250 box the app loads.

    Drawn light-on-dark because CSplash shows it over the app's own dark
    chrome before any theme has been applied.
    """
    from PIL import ImageDraw

    img = Image.new("RGBA", (width, height), (32, 36, 43, 255))
    d = ImageDraw.Draw(img)

    m = int(height * 0.42)
    art = recolour(mark, (255, 255, 255)).resize((m, m), Image.LANCZOS)
    img.paste(art, ((width - m) // 2, int(height * 0.16)), art)

    y = int(height * 0.16) + m + int(height * 0.06)
    for text, size, fill, bold in (("PW Docs", 0.13, (236, 240, 246), True),
                                   ("Document Editor", 0.062, (150, 160, 175), False)):
        f = _font(int(height * size), bold=bold)
        bb = d.textbbox((0, 0), text, font=f)
        d.text(((width - (bb[2] - bb[0])) / 2 - bb[0], y), text, font=f, fill=fill)
        y += (bb[3] - bb[1]) + int(height * 0.03)
    return img


with open(os.path.join(OUT, "splash.svg"), "w", encoding="utf-8") as f:
    f.write(svg_wrapping(splash(1000, 500), 500, 250))
print("wrote splash.svg")


ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
frames = sorted((app_tile(s) for s in ICO_SIZES),
                key=lambda i: i.width, reverse=True)
frames[0].save(os.path.join(OUT, "PWDocs.ico"), format="ICO",
               sizes=[(f.width, f.height) for f in frames],
               append_images=frames[1:])
frames[0].save(os.path.join(OUT, "PWDocs_256.png"))
print("wrote PWDocs.ico (%s)" % ", ".join(str(s) for s in ICO_SIZES))
