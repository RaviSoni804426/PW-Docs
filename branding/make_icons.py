"""Generate the PW Docs application and file-type icons.

Run from anywhere:  python branding/make_icons.py

Produces branding/icons/PWDocs.ico (app icon, replaces desktopeditors.ico)
plus one icon per associated document extension.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
os.makedirs(OUT, exist_ok=True)

DOC_BLUE = (41, 105, 176)
SIZES = [16, 24, 32, 48, 64, 128, 256]


def _font(px):
    for name in ("arialbd.ttf", "arial.ttf", "segoeuib.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    return ImageFont.load_default()


def sheet(draw, s, fill, shadow):
    """Draw a page with a folded top-right corner, return its bounding box."""
    m = max(2, s // 6)
    fold = max(2, s // 5)
    left, right = m, s - m
    top, bottom = max(1, s // 8), s - max(1, s // 8)
    draw.polygon(
        [(left, top), (right - fold, top), (right, top + fold), (right, bottom), (left, bottom)],
        fill=fill,
    )
    draw.polygon(
        [(right - fold, top), (right - fold, top + fold), (right, top + fold)],
        fill=shadow,
    )
    return left, top, right, bottom, fold


def app_icon(s):
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = max(1, s // 16)
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=max(2, s // 8), fill=DOC_BLUE)

    # White page inset in the blue tile.
    m = max(2, s // 5)
    fold = max(2, s // 6)
    left, right = m, s - m
    top, bottom = m, s - m
    d.polygon(
        [(left, top), (right - fold, top), (right, top + fold), (right, bottom), (left, bottom)],
        fill=(255, 255, 255, 245),
    )
    d.polygon(
        [(right - fold, top), (right - fold, top + fold), (right, top + fold)],
        fill=(214, 224, 236, 245),
    )

    # Text lines, shortest last, so it reads as a document at a glance.
    if s >= 32:
        pad_x = max(1, (right - left) // 6)
        x0, x1 = left + pad_x, right - pad_x
        y = top + fold + max(1, s // 14)
        gap = max(2, s // 10)
        thick = max(1, s // 32)
        n = 4 if s >= 64 else 3
        for i in range(n):
            if y + thick > bottom - max(1, s // 12):
                break
            xr = x1 if i < n - 1 else x0 + (x1 - x0) * 0.55
            d.rectangle([x0, y, xr, y + thick], fill=DOC_BLUE)
            y += gap
    return img


def filetype_icon(s, ext, color):
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    left, top, right, bottom, fold = sheet(
        d, s, (255, 255, 255, 250), (222, 228, 236, 250)
    )
    # Coloured band carrying the extension label.
    if s >= 32:
        band_h = max(6, s // 4)
        band_top = bottom - band_h - max(1, s // 16)
        d.rectangle([left, band_top, right, band_top + band_h], fill=color)
        f = _font(max(6, int(band_h * 0.72)))
        label = ext.upper()
        bb = d.textbbox((0, 0), label, font=f)
        d.text(
            (left + (right - left - (bb[2] - bb[0])) / 2 - bb[0],
             band_top + (band_h - (bb[3] - bb[1])) / 2 - bb[1]),
            label, fill=(255, 255, 255), font=f,
        )
        # Page rules above the band.
        pad_x = max(1, (right - left) // 8)
        y = top + fold + max(1, s // 12)
        gap = max(2, s // 12)
        thick = max(1, s // 40)
        while y + thick < band_top - gap:
            d.rectangle([left + pad_x, y, right - pad_x, y + thick], fill=(176, 186, 199))
            y += gap
    else:
        d.rectangle([left, bottom - max(3, s // 3), right, bottom], fill=color)
    return img


def save_ico(images, path):
    # Pillow's ICO writer resizes from the *base* image and never upscales,
    # so the largest frame has to go first or every entry collapses to the
    # smallest size.
    images = sorted(images, key=lambda im: im.width, reverse=True)
    images[0].save(path, format="ICO",
                   sizes=[(im.width, im.height) for im in images],
                   append_images=images[1:])


app = [app_icon(s) for s in SIZES]
save_ico(app, os.path.join(OUT, "PWDocs.ico"))
app[-1].save(os.path.join(OUT, "PWDocs_256.png"))
print("Created: PWDocs.ico, PWDocs_256.png")

EXTENSIONS = {
    "docx": (41, 105, 176),
    "doc":  (25, 79, 138),
    "dotx": (63, 126, 191),
    "odt":  (0, 121, 107),
    "ott":  (0, 137, 123),
    "rtf":  (84, 110, 122),
    "txt":  (96, 96, 96),
}
for ext, color in EXTENSIONS.items():
    save_ico([filetype_icon(s, ext, color) for s in SIZES],
             os.path.join(OUT, "filetype_%s.ico" % ext))
    print("Created: filetype_%s.ico" % ext)
